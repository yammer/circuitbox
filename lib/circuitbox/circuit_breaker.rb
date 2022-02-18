# frozen_string_literal: true

class Circuitbox
  class CircuitBreaker
    attr_reader :service, :circuit_options, :exceptions,
                :circuit_store, :notifier, :time_class

    DEFAULTS = {
      sleep_window: 90,
      volume_threshold: 5,
      error_threshold: 50,
      time_window: 60
    }.freeze

    # Initialize a CircuitBreaker
    #
    # @param service [String, Symbol] Name of the circuit for notifications and metrics store
    # @param options [Hash] Options to create the circuit with
    # @option options [Integer] :time_window (60) Interval of time, in seconds, used to calculate the error_rate
    # @option options [Integer, Proc] :sleep_window (90) Seconds for the circuit to stay open when tripped
    # @option options [Integer, Proc] :volume_threshold (5) Number of requests before error rate is first calculated
    # @option options [Integer, Proc] :error_threshold (50) Percentage of failed requests needed to trip the circuit
    # @option options [Array] :exceptions The exceptions that should be monitored and counted as failures
    # @option options [Circuitbox::MemoryStore, Moneta] :cache (Circuitbox.default_circuit_store) Class to store circuit open/close statistics
    # @option options [Object] :notifier (Circuitbox.default_notifier) Class notifications are sent to
    #
    # @raise [ArgumentError] If the exceptions option is not an Array
    def initialize(service, options = {})
      @service = service.to_s
      @circuit_options = DEFAULTS.merge(options)
      @circuit_store   = options.fetch(:cache) { Circuitbox.default_circuit_store }
      @notifier = options.fetch(:notifier) { Circuitbox.default_notifier }

      if @circuit_options[:timeout_seconds]
        warn('timeout_seconds was removed in circuitbox 2.0. '\
             'Check the upgrade guide at https://github.com/yammer/circuitbox')
      end

      @exceptions = options.fetch(:exceptions)
      raise ArgumentError.new('exceptions need to be an array') unless @exceptions.is_a?(Array)

      @time_class = options.fetch(:time_class) { Time }
      @state_change_mutex = Mutex.new
      check_sleep_window
    end

    def option_value(name)
      value = circuit_options[name]
      value.is_a?(Proc) ? value.call : value
    end

    # Run the circuit with the given block.
    # If the circuit is closed or half_open the block will run.
    # If the circuit is open the block will not be run.
    #
    # @param exception [Boolean] If exceptions should be raised when the circuit is open
    #   or when a watched exception is raised from the block
    # @yield Block to run if circuit is not open
    #
    # @raise [Circuitbox::OpenCircuitError] If the circuit is open and exception is true
    # @raise [Circuitbox::ServiceFailureError] If a tracked exception is raised from the block and exception is true
    #
    # @return [Object] The result from the block
    # @return [Nil] If the circuit is open and exception is false
    #   In cases where an exception that circuitbox is watching is raised from either a notifier
    #   or from a custom circuit cache nil can be returned even though the block ran successfully
    def run(exception: true, &block)
      if open?
        skipped!
        raise Circuitbox::OpenCircuitError.new(service) if exception
      else
        begin
          response = notifier.notify_run(service, &block)

          success!
        rescue *exceptions => e
          # Other stores could raise an exception that circuitbox is asked to watch.
          # setting to nil keeps the same behavior as the previous definition of run.
          response = nil
          failure!
          raise Circuitbox::ServiceFailureError.new(service, e) if exception
        end
      end

      response
    end

    # Check if the circuit is open
    #
    # @return [Boolean] True if circuit is open, False if closed
    def open?
      circuit_store.key?(open_storage_key)
    end

    # Calculates the current error rate of the circuit
    #
    # @return [Float] Error Rate
    def error_rate(failures = failure_count, success = success_count)
      all_count = failures + success
      return 0.0 unless all_count.positive?

      (failures / all_count.to_f) * 100
    end

    # Number of Failures the circuit has encountered in the current time window
    #
    # @return [Integer] Number of failures
    def failure_count
      circuit_store.load(stat_storage_key('failure'), raw: true).to_i
    end

    # Number of successes the circuit has encountered in the current time window
    #
    # @return [Integer] Number of successes
    def success_count
      circuit_store.load(stat_storage_key('success'), raw: true).to_i
    end

    # If the circuit is open the key indicating that the circuit is open
    # On the next call to run the circuit would run as if it were in the half open state
    #
    # This does not reset any of the circuit success/failure state so future failures
    # in the same time window may cause the circuit to open sooner
    def try_close_next_time
      circuit_store.delete(open_storage_key)
    end

    private

    def should_open?
      failures = failure_count
      successes = success_count
      rate = error_rate(failures, successes)

      passed_volume_threshold?(failures, successes) && passed_rate_threshold?(rate)
    end

    def passed_volume_threshold?(failures, successes)
      failures + successes >= option_value(:volume_threshold)
    end

    def passed_rate_threshold?(rate)
      rate >= option_value(:error_threshold)
    end

    def half_open_failure
      @state_change_mutex.synchronize do
        return if open? || !half_open?

        trip
      end

      # Running event outside of the synchronize block to allow other threads
      # that may be waiting to become unblocked
      notify_opened
    end

    def open!
      @state_change_mutex.synchronize do
        return if open?

        trip
      end

      # Running event outside of the synchronize block to allow other threads
      # that may be waiting to become unblocked
      notify_opened
    end

    def notify_opened
      notify_event('open')
    end

    def trip
      circuit_store.store(open_storage_key, true, expires: option_value(:sleep_window))
      circuit_store.store(half_open_storage_key, true)
    end

    def close!
      @state_change_mutex.synchronize do
        # If the circuit is not open, the half_open key will be deleted from the store
        # if half_open exists the deleted value is returned and allows us to continue
        # if half_open doesn't exist nil is returned, causing us to return early
        return unless !open? && circuit_store.delete(half_open_storage_key)
      end

      # Running event outside of the synchronize block to allow other threads
      # that may be waiting to become unblocked
      notify_event('close')
    end

    def half_open?
      circuit_store.key?(half_open_storage_key)
    end

    def success!
      increment_and_notify_event('success')

      close! if half_open?
    end

    def failure!
      increment_and_notify_event('failure')

      if half_open?
        half_open_failure
      elsif should_open?
        open!
      end
    end

    def skipped!
      notify_event('skipped')
    end

    # Send event notification to notifier
    def notify_event(event)
      notifier.notify(service, event)
    end

    # Increment stat store and send notification
    def increment_and_notify_event(event)
      circuit_store.increment(stat_storage_key(event), 1, expires: (option_value(:time_window) * 2))
      notify_event(event)
    end

    def check_sleep_window
      sleep_window = option_value(:sleep_window)
      time_window  = option_value(:time_window)
      return unless sleep_window < time_window

      warning_message = "sleep_window: #{sleep_window} is shorter than time_window: #{time_window}, "\
                        "the error_rate would not be reset after a sleep."
      notifier.notify_warning(service, warning_message)
      warn("Circuit: #{service}, Warning: #{warning_message}")
    end

    def stat_storage_key(event)
      "circuits:#{service}:stats:#{align_time_to_window}:#{event}"
    end

    # return time representation in seconds
    def align_time_to_window
      time = time_class.now.to_i
      time_window = option_value(:time_window)
      time - (time % time_window) # remove rest of integer division
    end

    def open_storage_key
      @open_storage_key ||= "circuits:#{service}:open"
    end

    def half_open_storage_key
      @half_open_storage_key ||= "circuits:#{service}:half_open"
    end
  end
end
