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
      check_sleep_window
    end

    def option_value(name)
      value = circuit_options[name]
      value.is_a?(Proc) ? value.call : value
    end

    def run!
      currently_open = open_flag?
      if currently_open || should_open?
        logger.debug(circuit_open_message)
        open! unless currently_open
        skipped!
        raise Circuitbox::OpenCircuitError.new(service)
      else
        close! if was_open?
        logger.debug(circuit_closed_querying_message)

        begin
          response = execution_timer.time(service, notifier, :execution_time) do
            yield
          end
          logger.debug(circuit_closed_query_success_message)
          success!
        rescue *exceptions => exception
          logger.debug(circuit_closed_failure_message)
          failure!
          open! if half_open?
          raise Circuitbox::ServiceFailureError.new(service, exception)
        end
      end

      response
    end

    def run
      run! { yield }
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
      circuit_store.load(stat_storage_key('failure'), raw: true).to_i
    end

    def success_count
      circuit_store.load(stat_storage_key('success'), raw: true).to_i
    end

    def try_close_next_time
      circuit_store.delete(storage_key('asleep'))
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

      half_open!
      was_open!
    end

    ### BEGIN - all this is just here to produce a close notification
    def close!
      notify_event('close')
      circuit_store.delete(storage_key('was_open'))
    end

    def was_open!
      circuit_store.store(storage_key('was_open'), true)
    end

    def was_open?
      circuit_store.key?(storage_key('was_open'))
    end
    ### END

    def half_open!
      circuit_store.store(storage_key('half_open'), true)
    end

    def open_flag?
      circuit_store.key?(storage_key('asleep'))
    end

    def half_open?
      circuit_store.key?(storage_key('half_open'))
    end

    def success!
      notify_and_increment_event('success')
      circuit_store.delete(storage_key('half_open'))
    end

    def failure!
      notify_and_increment_event('failure')
    end

    def skipped!
      notify_event('skipped')
    end

    # Send event notification to notifier
    def notify_event(event)
      notifier.notify(service, event)
    end

    # Send notification and increment stat store
    def notify_and_increment_event(event)
      notify_event(event)
      circuit_store.increment(stat_storage_key(event), 1, expires: (option_value(:time_window) * 2))
    end

    def log_metrics(error_rate, failures, successes)
      notifier.metric_gauge(service, :error_rate, error_rate)
      notifier.metric_gauge(service, :failure_count, failures)
      notifier.metric_gauge(service, :success_count, successes)
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

    def storage_key(key)
      "circuits:#{service}:#{key}"
    end
  end
end
