# frozen_string_literal: true

require 'test_helper'
require 'circuitbox/timer/null'

class CircuitBreakerTest < Minitest::Test
  class ConnectionError < StandardError; end

  def setup
    Circuitbox.configure { |config| config.default_circuit_store = Moneta.new(:Memory, expires: true) }
  end

  def test_goes_into_half_open_state_on_sleep
    circuit = Circuitbox::CircuitBreaker.new(:yammer, exceptions: [Timeout::Error])
    circuit.send(:open!)
    assert circuit.send(:half_open?)
  end

  class Ratio < Minitest::Test
    def setup
      Circuitbox.configure { |config| config.default_circuit_store = Moneta.new(:Memory, expires: true) }
      @circuit = Circuitbox::CircuitBreaker.new(:yammer,
                                                sleep_window: 300,
                                                volume_threshold: 5,
                                                error_threshold: 33,
                                                exceptions: [Timeout::Error])
    end

    def test_open_circuit_on_100_percent_failure
      run_counter = 0
      10.times do
        @circuit.run do
          run_counter += 1
          raise Timeout::Error
        end
      end
      assert_equal 5, run_counter, 'the circuit did not open after 5 failures'
    end

    def test_keep_circuit_closed_on_success
      run_counter = 0
      10.times do
        @circuit.run do
          run_counter += 1
          'sucess'
        end
      end
      assert_equal 10, run_counter, 'run block was not executed 10 times'
    end

    def test_open_circuit_on_low_success_rate_below_limit
      run_counter = 0
      5.times do
        @circuit.run do
          run_counter += 1
          raise Timeout::Error
        end
      end

      # one success
      @circuit.run { 'success' }
      assert_equal 5, @circuit.failure_count, 'the total count of failures is not 5'

      5.times do
        @circuit.run do
          run_counter += 1
          raise Timeout::Error
        end
      end
      assert_equal 5, run_counter, 'the circuit did not open after 5 failures (5 failures + 10%)'
    end

    def test_keep_circuit_closed_on_low_failure_rate_below_failure_limit
      run_counter = 0
      7.times do
        @circuit.run do
          run_counter += 1
          'sucess'
        end
      end
      assert_equal 0, @circuit.failure_count, 'some errors were counted'

      3.times do
        @circuit.run do
          run_counter += 1
          raise Timeout::Error
        end
      end
      assert_equal 10, run_counter, 'block was not executed 10 times'
      assert @circuit.error_rate < 33, 'error_rate pass over 33%'
    end

    def test_open_circuit_on_high_failure_rate_exceeding_failure_limit
      run_counter = 0
      10.times do
        @circuit.run do
          run_counter += 1
          'sucess'
        end
      end
      assert_equal 0, @circuit.failure_count, 'some errors were counted'

      10.times do
        @circuit.run do
          run_counter += 1
          raise Timeout::Error
        end
      end
      # 5 failure on 15 run is 33%
      assert_equal 15, run_counter, 'block was not executed 10 times'
      assert @circuit.error_rate >= 33, 'error_rate pass over 33%'
    end
  end

  class CacheExpiration < Minitest::Test
    class ExpiringCache < Moneta::Adapters::Memory
      def initialize(expiring_key, initial_value)
        super()
        @expiring_key = expiring_key
        store(expiring_key, initial_value)
      end

      def key?(key, options = {})
        if key == @expiring_key
          @expiring_key = nil # only override the first call
          value = super
          delete(key)
          return value
        end
        super
      end
    end

    def setup
      @circuit = Circuitbox::CircuitBreaker.new(:yammer,
                                                exceptions: [Timeout::Error],
                                                cache: ExpiringCache.new('circuits:yammer:asleep', true))
    end

    def test_key_expiration_closes_circuit
      assert_raises(Circuitbox::OpenCircuitError) { @circuit.run! {} }
      assert_equal 'success', @circuit.run! { 'success' }
    end
  end


  class Exceptions < Minitest::Test
    class SentinalError < StandardError; end

    def setup
      Circuitbox.configure { |config| config.default_circuit_store = Moneta.new(:Memory, expires: true) }
      @circuit = Circuitbox::CircuitBreaker.new(:yammer, exceptions: [SentinalError])
    end

    def test_raises_when_circuit_is_open
      @circuit.stubs(open_flag?: true)
      assert_raises(Circuitbox::OpenCircuitError) { @circuit.run! {} }
    end

    def test_raises_on_service_failure
      assert_raises(Circuitbox::ServiceFailureError) { @circuit.run! { raise SentinalError } }
    end

    def test_sets_original_error_on_service_failure
      @circuit.run! { raise SentinalError }
    rescue Circuitbox::ServiceFailureError => service_failure_error
      assert_instance_of SentinalError, service_failure_error.original
    end

    def test_raises_argument_error_when_exceptions_is_not_an_array
      assert_raises(ArgumentError) { Circuitbox::CircuitBreaker.new(:yammer, exceptions: nil) }
    end
  end

  class CloseAfterSleep < Minitest::Test
    def setup
      Circuitbox.configure { |config| config.default_circuit_store = Moneta.new(:Memory, expires: true) }
      @circuit = Circuitbox::CircuitBreaker.new(:yammer,
                                                sleep_window: 2,
                                                time_window: 2,
                                                volume_threshold: 5,
                                                error_threshold: 50,
                                                exceptions: [Timeout::Error])
    end

    def test_circuit_closes_after_sleep_time_window
      current_time = Time.new(2015, 7, 29)
      run_count = 0

      Timecop.freeze(current_time) do
        open_circuit!
        # should_open? calculation happens when run is called here
        @circuit.run { run_count += 1 }
      end

      assert_equal 0, run_count, 'circuit has not opened prior'

      # We need to be past the sleep window for the circuit to close
      # which is why we are adding 1 second to the sleep window
      approximate_sleep_window = @circuit.option_value(:sleep_window) + 1

      Timecop.freeze(current_time + approximate_sleep_window) do
        @circuit.run { run_count += 1 }
      end

      assert_equal 1, run_count, 'circuit did not close after sleep'
    end

    def open_circuit!
      @circuit.option_value(:volume_threshold).times { @circuit.run { raise Timeout::Error } }
    end
  end

  class HalfOpenState < Minitest::Test
    def setup
      Circuitbox.configure { |config| config.default_circuit_store = Moneta.new(:Memory, expires: true) }
      @circuit = Circuitbox::CircuitBreaker.new(:yammer, exceptions: [Timeout::Error])
    end

    def test_when_in_half_open_state_circuit_opens_on_failure
      @circuit.stubs(half_open?: true)
      @circuit.expects(:open!)
      @circuit.run { raise Timeout::Error }
    end

    def test_when_in_half_open_state_circuit_closes_on_success
      @circuit.send(:half_open!)
      @circuit.run { 'success' }
      refute @circuit.send(:half_open?)
      refute @circuit.send(:open?)
    end
  end

  def test_raises_key_error_when_exceptions_not_defined
    assert_raises(KeyError) do
      Circuitbox::CircuitBreaker.new(:yammer)
    end
  end

  def test_uses_the_defined_exceptions
    circuit = Circuitbox::CircuitBreaker.new(:yammer, exceptions: [ConnectionError])
    assert_equal [ConnectionError], circuit.exceptions
  end

  def test_should_return_response_if_it_doesnt_timeout
    circuit = Circuitbox::CircuitBreaker.new(:yammer, exceptions: [Timeout::Error])
    response = emulate_circuit_run(circuit, :success, 'success')
    assert_equal 'success', response
  end

  def test_catches_connection_error_failures_if_defined
    circuit = Circuitbox::CircuitBreaker.new(:yammer, exceptions: [ConnectionError])
    response = emulate_circuit_run(circuit, :failure, ConnectionError)
    assert_nil response
  end

  def test_doesnt_catch_out_of_scope_exceptions
    sentinal = Class.new(StandardError)
    circuit = Circuitbox::CircuitBreaker.new(:yammer, exceptions: [ConnectionError, Timeout::Error])

    assert_raises(sentinal) do
      emulate_circuit_run(circuit, :failure, sentinal)
    end
  end

  def test_records_response_failure
    circuit = Circuitbox::CircuitBreaker.new(:yammer, exceptions: [Timeout::Error])
    circuit.expects(:notify_and_increment_event).with('failure')
    emulate_circuit_run(circuit, :failure, Timeout::Error)
  end

  def test_records_response_skipped
    circuit = Circuitbox::CircuitBreaker.new(:yammer, exceptions: [Timeout::Error])
    circuit.stubs(should_open?: true)
    circuit.stubs(:notify_event)
    circuit.expects(:notify_event).with('skipped')
    emulate_circuit_run(circuit, :failure, Timeout::Error)
  end

  def test_records_response_success
    circuit = Circuitbox::CircuitBreaker.new(:yammer, exceptions: [Timeout::Error])
    circuit.expects(:notify_and_increment_event).with('success')
    emulate_circuit_run(circuit, :success, 'success')
  end

  def test_does_not_send_request_if_circuit_is_open
    circuit = Circuitbox::CircuitBreaker.new(:yammer, exceptions: [Timeout::Error])
    circuit.stubs(open?: true)
    circuit.expects(:yield).never
    response = emulate_circuit_run(circuit, :failure, Timeout::Error)
    assert_nil response
  end

  def test_returns_nil_response_on_failed_request
    circuit = Circuitbox::CircuitBreaker.new(:yammer, exceptions: [Timeout::Error])
    response = emulate_circuit_run(circuit, :failure, Timeout::Error)
    assert_nil response
  end

  def test_puts_circuit_to_sleep_once_opened
    circuit = Circuitbox::CircuitBreaker.new(:yammer, exceptions: [Timeout::Error])
    circuit.stubs(should_open?: true)

    assert !circuit.send(:open_flag?)
    emulate_circuit_run(circuit, :failure, Timeout::Error)
    assert circuit.send(:open_flag?)

    circuit.expects(:open!).never
    emulate_circuit_run(circuit, :failure, Timeout::Error)
  end

  def test_open_is_true_if_open_flag
    circuit = Circuitbox::CircuitBreaker.new(:yammer, exceptions: [Timeout::Error])
    circuit.stubs(open_flag?: true)
    assert circuit.open?
  end

  def test_open_checks_if_volume_threshold_has_passed
    circuit = Circuitbox::CircuitBreaker.new(:yammer, exceptions: [Timeout::Error])
    circuit.stubs(open_flag?: false)

    circuit.expects(:passed_volume_threshold?).with(0, 0).once
    circuit.open?
  end

  def test_open_checks_error_rate_threshold
    circuit = Circuitbox::CircuitBreaker.new(:yammer, exceptions: [Timeout::Error])
    circuit.stubs(open_flag?: false,
                  passed_volume_threshold?: true)

   circuit.expects(:passed_rate_threshold?).with(0.0).once
   circuit.open?
  end

  def test_open_is_false_if_awake_and_under_rate_threshold
    circuit = Circuitbox::CircuitBreaker.new(:yammer, exceptions: [Timeout::Error])
    circuit.stubs(open_flag?: false,
                  passed_volume_threshold?: false,
                  passed_rate_threshold: false)

    assert !circuit.open?
  end

  def test_logs_and_retrieves_success_events
    circuit = Circuitbox::CircuitBreaker.new(:yammer, exceptions: [Timeout::Error])
    5.times { circuit.send(:notify_and_increment_event, 'success') }
    assert_equal 5, circuit.success_count
  end

  def test_logs_and_retrieves_failure_events
    circuit = Circuitbox::CircuitBreaker.new(:yammer, exceptions: [Timeout::Error])
    5.times { circuit.send(:notify_and_increment_event, 'failure') }
    assert_equal 5, circuit.failure_count
  end

  def test_logs_events_by_minute
    circuit = Circuitbox::CircuitBreaker.new(:yammer, exceptions: [Timeout::Error])
    current_time = Time.new(2015, 7, 29)

    Timecop.freeze(current_time) do
      4.times { circuit.send(:notify_and_increment_event, 'success') }
      assert_equal 4, circuit.success_count
    end

    # one minute after current_time
    Timecop.freeze(current_time + 60) do
      7.times { circuit.send(:notify_and_increment_event, 'success') }
      assert_equal 7, circuit.success_count
    end

    # one minute 30 seconds after current_time
    Timecop.freeze(current_time + 90) do
      circuit.send(:notify_and_increment_event, 'success')
      assert_equal 8, circuit.success_count
    end

    # two minutes 20 seconds after current_time
    Timecop.freeze(current_time + 140) do
      assert_equal 0, circuit.success_count
    end
  end

  class Notifications < Minitest::Test
    def setup
      Circuitbox.configure { |config| config.default_circuit_store = Moneta.new(:Memory, expires: true) }
    end

    def test_notification_on_open
      notifier = gimme_notifier
      circuit = Circuitbox::CircuitBreaker.new(:yammer,
                                               notifier: notifier,
                                               exceptions: [Timeout::Error])
      10.times { circuit.run { raise Timeout::Error } }
      assert notifier.notified?, 'no notification sent'
    end

    def test_notification_on_close
      notifier = gimme_notifier
      circuit = Circuitbox::CircuitBreaker.new(:yammer,
                                               notifier: notifier,
                                               exceptions: [Timeout::Error])
      5.times { circuit.run { raise Timeout::Error } }
      notifier.clear_notified!
      10.times { circuit.run { 'success' } }
      assert notifier.notified?, 'no notification sent'
    end

    def test_warning_when_sleep_window_is_shorter_than_time_window
      notifier = gimme_notifier
      _, error = capture_io do
        Circuitbox::CircuitBreaker.new(:yammer,
                                       notifier: notifier,
                                       sleep_window: 1,
                                       time_window: 10,
                                       exceptions: [Timeout::Error])
      end
      assert notifier.notified?, 'no notification sent'
      assert_match(/Circuit: yammer.+sleep_window: 1.+time_window: 10.+/, error)
    end

    def test_does_not_warn_on_sleep_window_being_correctly_sized
      notifier = gimme_notifier
      Circuitbox::CircuitBreaker.new(:yammer,
                                     notifier: notifier,
                                     sleep_window: 11,
                                     time_window: 10,
                                     exceptions: [Timeout::Error])
      assert_equal false, notifier.notified?, 'no notification sent'
    end

    def test_notifies_on_success_rate_calculation
      notifier = gimme_notifier(metric: 'error_rate', metric_value: 0.0)
      circuit = Circuitbox::CircuitBreaker.new(:yammer,
                                               notifier: notifier,
                                               exceptions: [Timeout::Error])
      10.times { circuit.run { 'success' } }
      assert notifier.notified?, 'no notification sent'
    end

    def test_notifies_on_error_rate_calculation
      notifier = gimme_notifier(metric: 'failure_count', metric_value: 1)
      circuit = Circuitbox::CircuitBreaker.new(:yammer,
                                               notifier: notifier,
                                               exceptions: [Timeout::Error])
      10.times { circuit.run { raise Timeout::Error } }
      assert notifier.notified?, 'no notification sent'
    end

    def test_success_count_on_error_rate_calculation
      notifier = gimme_notifier(metric: 'success_count', metric_value: 6)
      circuit = Circuitbox::CircuitBreaker.new(:yammer,
                                               notifier: notifier,
                                               exceptions: [Timeout::Error])
      10.times { circuit.run { 'success' } }
      assert notifier.notified?, 'no notification sent'
    end

    def test_not_notify_circuit_execution_time_on_null_timer
      notifier = gimme_notifier(metric: 'execution_time', metric_value: Gimme::Matchers::Anything.new)
      timer = Circuitbox::Timer::Null.new
      circuit = Circuitbox::CircuitBreaker.new(:yammer,
                                               notifier: notifier,
                                              execution_timer: timer,
                                              exceptions: [Timeout::Error])
      circuit.run { 'success' }
      refute notifier.metric_sent?, 'execution time metric sent'
    end

    def test_send_execution_time_metric
      notifier = gimme_notifier(metric: 'execution_time', metric_value: Gimme::Matchers::Anything.new)
      circuit = Circuitbox::CircuitBreaker.new(:yammer,
                                               notifier: notifier,
                                               exceptions: [Timeout::Error])
      circuit.run { 'success' }
      assert notifier.metric_sent?, 'no execution time metric sent'
    end

    def test_no_execution_time_metric_on_error_execution
      notifier = gimme_notifier(metric: 'execution_time', metric_value: Gimme::Matchers::Anything.new)
      circuit = Circuitbox::CircuitBreaker.new(:yammer,
                                               notifier: notifier,
                                               exceptions: [Timeout::Error])
      circuit.run { raise Timeout::Error }
      refute notifier.metric_sent?, 'execution time metric sent'
    end

    def test_no_execution_time_metric_when_circuit_open
      notifier = gimme_notifier(metric: 'execution_time', metric_value: Gimme::Matchers::Anything.new)
      circuit = Circuitbox::CircuitBreaker.new(:yammer,
                                               notifier: notifier,
                                               exceptions: [Timeout::Error])
      circuit.send(:open!)
      circuit.run { raise Timeout::Error }
      refute notifier.metric_sent?, 'execution time metric sent'
    end

    def gimme_notifier(opts = {})
      service = opts.fetch(:service, 'yammer').to_s
      metric = opts.fetch(:metric, 'error_rate')
      metric_value = opts.fetch(:metric_value, 0.0)
      fake_notifier = gimme
      notified = false
      metric_sent = false
      give(fake_notifier).notify(service, 'open') { notified = true }
      give(fake_notifier).notify(service, 'close') { notified = true }
      give(fake_notifier).notify_warning(service, Gimme::Matchers::Anything.new) { notified = true }
      give(fake_notifier).metric_gauge(service, metric, metric_value) do
        notified = true
        metric_sent = true
      end
      give(fake_notifier).notified? { notified }
      give(fake_notifier).metric_sent? { metric_sent }
      give(fake_notifier).clear_notified! { notified = false }
      fake_notifier
    end
  end

  def emulate_circuit_run(circuit, response_type, response_value)
    circuit.run do
      case response_type
      when :failure
        raise response_value
      when :success
        response_value
      end
    end
  rescue Timeout::Error
    nil
  end
end
