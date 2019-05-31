# frozen_string_literal: true

require_relative 'circuit_breaker/logger_messages'

class Circuitbox
  class CircuitBreaker
    include LoggerMessages

    attr_reader :service, :circuit_options, :exceptions,
                :logger, :circuit_store, :notifier, :time_class, :execution_timer

    DEFAULTS = {
      sleep_window:     90,
      volume_threshold: 5,
      error_threshold:  50,
      time_window:      60
    }.freeze

    #
    # Configuration options
    #
    # `sleep_window`      - seconds to sleep the circuit
    # `volume_threshold`  - number of requests before error rate calculation occurs
    # `error_threshold`   - percentage of failed requests needed to trip circuit
    # `exceptions`        - exceptions that count as failures
    # `time_window`       - interval of time used to calculate error_rate (in seconds) - default is 60s
    # `logger`            - Logger to use - defaults to Rails.logger if defined, otherwise STDOUT
    #
    def initialize(service, options = {})
      @service = service.to_s
      @circuit_options = DEFAULTS.merge(options)
      @circuit_store   = options.fetch(:cache) { Circuitbox.default_circuit_store }
      @execution_timer = options.fetch(:execution_timer) { Circuitbox.default_timer }
      @notifier = options.fetch(:notifier) { Circuitbox.default_notifier }

      if @circuit_options[:timeout_seconds]
        warn('timeout_seconds was removed in circuitbox 2.0. '\
             'Check the upgrade guide at https://github.com/yammer/circuitbox')
      end

      @exceptions = options.fetch(:exceptions)
      raise ArgumentError, 'exceptions need to be an array' unless @exceptions.is_a?(Array)

      @logger     = options.fetch(:logger) { Circuitbox.default_logger }
      @time_class = options.fetch(:time_class) { Time }
      @state_change_mutex = Mutex.new
      check_sleep_window
    end

    def option_value(name)
      value = circuit_options[name]
      value.is_a?(Proc) ? value.call : value
    end

    def run(circuitbox_exceptions: true)
      if open?
        skipped!
        raise Circuitbox::OpenCircuitError.new(service) if circuitbox_exceptions
      else
        logger.debug(circuit_running_message)

        begin
          response = execution_timer.time(service, notifier, 'execution_time') do
            yield
          end

          success!
        rescue *exceptions => exception
          # Other stores could raise an exception that circuitbox is asked to watch.
          # setting to nil keeps the same behavior as the previous defination of run.
          response = nil
          failure!
          raise Circuitbox::ServiceFailureError.new(service, exception) if circuitbox_exceptions
        end
      end

      response
    end

    def open?
      circuit_store.key?(open_storage_key)
    end

    def error_rate(failures = failure_count, success = success_count)
      all_count = failures + success
      return 0.0 unless all_count > 0
      (failures / all_count.to_f) * 100
    end

    def failure_count
      circuit_store.load(stat_storage_key('failure'), raw: true).to_i
    end

    def success_count
      circuit_store.load(stat_storage_key('success'), raw: true).to_i
    end

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

      # Running event and logger outside of the synchronize block to allow other threads
      # that may be waiting to become unblocked
      notify_opened
    end

    def open!
      @state_change_mutex.synchronize do
        return if open?

        trip
      end

      # Running event and logger outside of the synchronize block to allow other threads
      # that may be waiting to become unblocked
      notify_opened
    end

    def notify_opened
      notify_event('open')
      logger.debug(circuit_opened_message)
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
      logger.debug(circuit_closed_message)
    end

    def half_open?
      circuit_store.key?(half_open_storage_key)
    end

    def success!
      increment_and_notify_event('success')
      logger.debug(circuit_success_message)

      close! if half_open?
    end

    def failure!
      increment_and_notify_event('failure')
      logger.debug(circuit_failure_message)

      if half_open?
        half_open_failure
      elsif should_open?
        open!
      end
    end

    def skipped!
      notify_event('skipped')
      logger.debug(circuit_skipped_message)
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
      if sleep_window < time_window
        warning_message = "sleep_window: #{sleep_window} is shorter than time_window: #{time_window}, "\
                          "the error_rate would not be reset after a sleep."
        notifier.notify_warning(service, warning_message)
        warn("Circuit: #{service}, Warning: #{warning_message}")
      end
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
