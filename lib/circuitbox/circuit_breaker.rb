class Circuitbox
  class CircuitBreaker
    attr_accessor :service, :circuit_options, :exceptions, :partition,
                  :logger, :circuit_store, :notifier

    DEFAULTS = {
      sleep_window:     300,
      volume_threshold: 5,
      error_threshold:  50,
      timeout_seconds:  1,
      time_window:      60,
    }

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
      @service = service
      @circuit_options = options
      @circuit_store   = options.fetch(:cache) { Circuitbox.circuit_store }
      @notifier        = options.fetch(:notifier_class) { Notifier }

      @exceptions = options.fetch(:exceptions) { [] }
      @exceptions = [Timeout::Error] if @exceptions.blank?

      @logger     = options.fetch(:logger) { defined?(Rails) ? Rails.logger : Logger.new(STDOUT) }
      @time_class   = options.fetch(:time_class) { Time }
      sanitize_options
    end

    def option_value(name)
      value = circuit_options.fetch(name) { DEFAULTS.fetch(name) }
      value.is_a?(Proc) ? value.call : value
    end

    def run!(run_options = {})
      @partition = run_options.delete(:partition) # sorry for this hack.

      if open?
        logger.debug "[CIRCUIT] open: skipping #{service}"
        open! unless open_flag?
        skipped!
        raise Circuitbox::OpenCircuitError.new(service)
      else
        close! if was_open?
        logger.debug "[CIRCUIT] closed: querying #{service}"

        begin
          response = if exceptions.include? Timeout::Error
            timeout_seconds = run_options.fetch(:timeout_seconds) { option_value(:timeout_seconds) }
            timeout (timeout_seconds) { yield }
          else
            yield
          end

          logger.debug "[CIRCUIT] closed: #{service} querie success"
          success!
        rescue *exceptions => exception
          logger.debug "[CIRCUIT] closed: detected #{service} failure"
          failure!
          open! if half_open?
          raise Circuitbox::ServiceFailureError.new(service, exception)
        end
      end

      return response
    end

    def run(run_options = {})
      begin
        run!(run_options, &Proc.new)
      rescue Circuitbox::Error
        nil
      end
    end

    def open?
      if open_flag?
        true
      elsif passed_volume_threshold? && passed_rate_threshold?
        true
      else
        false
      end
    end

    def error_rate(failures = failure_count, success = success_count)
      all_count = failures + success
      return 0.0 unless all_count > 0
      failure_count.to_f / all_count.to_f * 100
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
    def open!
      log_event :open
      logger.debug "[CIRCUIT] opening #{service} circuit"
      circuit_store.store(storage_key(:asleep), true, expires: option_value(:sleep_window))
      half_open!
      was_open!
    end

    ### BEGIN - all this is just here to produce a close notification
    def close!
      log_event :close
      circuit_store.delete(storage_key(:was_open))
    end

    def was_open!
      circuit_store.store(storage_key(:was_open), true)
    end

    def was_open?
      circuit_store[storage_key(:was_open)].present?
    end
    ### END

    def half_open!
      circuit_store.store(storage_key(:half_open), true)
    end

    def open_flag?
      circuit_store[storage_key(:asleep)].present?
    end

    def half_open?
      circuit_store[storage_key(:half_open)].present?
    end

    def passed_volume_threshold?
      success_count + failure_count > option_value(:volume_threshold)
    end

    def passed_rate_threshold?
      read_and_log_error_rate >= option_value(:error_threshold)
    end

    def read_and_log_error_rate
      failures = failure_count
      success  = success_count
      rate = error_rate(failures, success)
      log_metrics(rate, failures, success)
      rate
    end

    def success!
      log_event :success
      circuit_store.delete(storage_key(:half_open))
    end

    def failure!
      log_event :failure
    end

    def skipped!
      log_event :skipped
    end

    # Store success/failure/open/close data in memcache
    def log_event(event)
      notifier.new(service,partition).notify(event)
      log_event_to_process(event)
    end

    def log_metrics(error_rate, failures, successes)
      n = notifier.new(service,partition)
      n.metric_gauge(:error_rate, error_rate)
      n.metric_gauge(:failure_count, failures)
      n.metric_gauge(:success_count, successes)
    end

    def sanitize_options
      sleep_window = option_value(:sleep_window)
      time_window  = option_value(:time_window)
      if sleep_window < time_window
        notifier.new(service,partition).notify_warning("sleep_window:#{sleep_window} is shorter than time_window:#{time_window}, the error_rate could not be reset properly after a sleep. sleep_window as been set to equal time_window.")
        @circuit_options[:sleep_window] = option_value(:time_window)
      end
    end

    # When there is a successful response within a count interval, clear the failures.
    def clear_failures!
      circuit_store.store(stat_storage_key(:failure), 0, raw: true)
    end

    # Logs to process memory.
    def log_event_to_process(event)
      key = stat_storage_key(event)
      if circuit_store.load(key, raw: true)
        circuit_store.increment(key)
      else
        # yes we want a string here, as the underlying stores impement this as a native type.
        circuit_store.store(key, "1", raw: true)
      end
    end

    # Logs to Memcache.
    def log_event_to_stat_store(key)
      if stat_store.read(key, raw: true)
        stat_store.increment(key)
      else
        stat_store.store(key, 1)
      end
    end

    # For returning stale responses when the circuit is open
    def response_key(args)
      Digest::SHA1.hexdigest(storage_key(:cache, args.inspect.to_s))
    end

    def stat_storage_key(event, options = {})
      storage_key(:stats, align_time_on_minute, event, options)
    end


    # return time representation in seconds
    def align_time_on_minute(time=nil)
      time      ||= @time_class.now.to_i
      time_window = option_value(:time_window)
      time - ( time % time_window ) # remove rest of integer division
    end

    def storage_key(*args)
      options = args.extract_options!

      key = if options[:without_partition]
        "circuits:#{service}:#{args.join(":")}"
      else
        "circuits:#{service}:#{partition}:#{args.join(":")}"
      end

      return key
    end

    def timeout(timeout_seconds, &block)
      Timeout::timeout(timeout_seconds) { block.call }
    end

    def self.reset
      Circuitbox.reset
    end

  end
end
