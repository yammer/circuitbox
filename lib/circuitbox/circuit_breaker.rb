class Circuitbox
  class CircuitBreaker
    attr_reader :service, :circuit_options, :exceptions,
                :logger, :circuit_store, :notifier, :time_class, :execution_timer

    DEFAULTS = {
      sleep_window:     300,
      volume_threshold: 5,
      error_threshold:  50,
      timeout_seconds:  1,
      time_window:      60
    }.freeze

    #
    # Configuration options
    #
    # `sleep_window`      - seconds to sleep the circuit
    # `volume_threshold`  - number of requests before error rate calculation occurs
    # `error_threshold`   - percentage of failed requests needed to trip circuit
    # `timeout_seconds`   - seconds until it will timeout the request
    # `exceptions`        - exceptions other than Timeout::Error that count as failures
    # `time_window`       - interval of time used to calculate error_rate (in seconds) - default is 60s
    # `logger`            - Logger to use - defaults to Rails.logger if defined, otherwise STDOUT
    #
    def initialize(service, options = {})
      @service = service.to_s
      @circuit_options = DEFAULTS.merge(options)
      @circuit_store   = options.fetch(:cache) { Circuitbox.default_circuit_store }
      @execution_timer = options.fetch(:execution_timer) { Circuitbox.default_timer }
      @notifier = options.fetch(:notifier) { Circuitbox.default_notifier }

      @exceptions = options.fetch(:exceptions) { [] }
      raise ArgumentError, 'exceptions need to be an array'.freeze unless @exceptions.is_a?(Array)
      @exceptions = [Timeout::Error] if @exceptions.empty?

      @logger     = options.fetch(:logger) { Circuitbox.default_logger }
      @time_class = options.fetch(:time_class) { Time }
      sanitize_options
    end

    def option_value(name)
      value = circuit_options[name]
      value.is_a?(Proc) ? value.call : value
    end

    def run!(run_options = {})
      currently_open = open_flag?
      if currently_open || should_open?
        logger.debug "[CIRCUIT] open: skipping #{service}"
        open! unless currently_open
        skipped!
        raise Circuitbox::OpenCircuitError.new(service)
      else
        close! if was_open?
        logger.debug "[CIRCUIT] closed: querying #{service}"

        begin
          response = execution_timer.time(service, notifier, :execution_time) do
            if exceptions.include? Timeout::Error
              timeout_seconds = run_options.fetch(:timeout_seconds) { option_value(:timeout_seconds) }
              Timeout::timeout(timeout_seconds) { yield }
            else
              yield
            end
          end
          logger.debug "[CIRCUIT] closed: #{service} query success"
          success!
        rescue *exceptions => exception
          logger.debug "[CIRCUIT] closed: detected #{service} failure"
          failure!
          open! if half_open?
          raise Circuitbox::ServiceFailureError.new(service, exception)
        end
      end

      response
    end

    def run(run_options = {})
      run!(run_options, &Proc.new)
    rescue Circuitbox::Error
      nil
    end

    def open?
      if open_flag?
        true
      elsif should_open?
        true
      else
        false
      end
    end

    def error_rate(failures = failure_count, success = success_count)
      all_count = failures + success
      return 0.0 unless all_count > 0
      (failures / all_count.to_f) * 100
    end

    def failure_count
      circuit_store.load(stat_storage_key(:failure), raw: true).to_i
    end

    def success_count
      circuit_store.load(stat_storage_key(:success), raw: true).to_i
    end

    def try_close_next_time
      circuit_store.delete(storage_key(:asleep))
    end

  private

    def should_open?
      failures = failure_count
      successes = success_count
      rate = error_rate(failures, successes)

      log_metrics(rate, failures, successes)

      passed_volume_threshold?(failures, successes) && passed_rate_threshold?(rate)
    end

    def passed_volume_threshold?(failures, successes)
      failures + successes > option_value(:volume_threshold)
    end

    def passed_rate_threshold?(rate)
      rate >= option_value(:error_threshold)
    end

    def open!
      notify_event :open
      logger.debug "[CIRCUIT] opening #{service} circuit"
      circuit_store.store(storage_key(:asleep), true, expires: option_value(:sleep_window))
      half_open!
      was_open!
    end

    ### BEGIN - all this is just here to produce a close notification
    def close!
      notify_event :close
      circuit_store.delete(storage_key(:was_open))
    end

    def was_open!
      circuit_store.store(storage_key(:was_open), true)
    end

    def was_open?
      circuit_store.key?(storage_key(:was_open))
    end
    ### END

    def half_open!
      circuit_store.store(storage_key(:half_open), true)
    end

    def open_flag?
      circuit_store.key?(storage_key(:asleep))
    end

    def half_open?
      circuit_store.key?(storage_key(:half_open))
    end

    def success!
      notify_and_increment_event :success
      circuit_store.delete(storage_key(:half_open))
    end

    def failure!
      notify_and_increment_event :failure
    end

    def skipped!
      notify_event :skipped
    end

    # Send event notification to notifier
    def notify_event(event)
      notifier.notify(service, event)
    end

    # Send notification and increment stat store
    def notify_and_increment_event(event)
      notify_event(event)
      circuit_store.increment(stat_storage_key(event))
    end

    def log_metrics(error_rate, failures, successes)
      notifier.metric_gauge(service, :error_rate, error_rate)
      notifier.metric_gauge(service, :failure_count, failures)
      notifier.metric_gauge(service, :success_count, successes)
    end

    def sanitize_options
      sleep_window = option_value(:sleep_window)
      time_window  = option_value(:time_window)
      if sleep_window < time_window
        notifier.notify_warning(service, "sleep_window:#{sleep_window} is shorter than time_window:#{time_window}, the error_rate could not be reset properly after a sleep. sleep_window as been set to equal time_window.")
        @circuit_options[:sleep_window] = option_value(:time_window)
      end
    end

    def stat_storage_key(event)
      "#{storage_key('stats'.freeze)}:#{align_time_to_window}:#{event}"
    end

    # return time representation in seconds
    def align_time_to_window
      time = time_class.now.to_i
      time_window = option_value(:time_window)
      time - (time % time_window) # remove rest of integer division
    end

    def storage_key(key)
      "circuits:#{service}:#{key}"
    end
  end
end
