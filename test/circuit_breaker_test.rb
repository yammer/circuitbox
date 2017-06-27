require 'test_helper'

class CircuitBreakerTest < Minitest::Test
  class ConnectionError < StandardError; end;

  def setup
    Circuitbox::CircuitBreaker.reset
  end

  def test_sleep_window_is_forced_to_equal_time_window
    circuit = Circuitbox::CircuitBreaker.new(:yammer, sleep_window: 1, time_window: 10)
    assert_equal circuit.option_value(:sleep_window), circuit.option_value(:time_window)
  end

  def test_goes_into_half_open_state_on_sleep
    circuit = Circuitbox::CircuitBreaker.new(:yammer)
    circuit.send(:open!)
    assert circuit.send(:half_open?)
  end

  class Ratio < Minitest::Test
    def setup
      Circuitbox::CircuitBreaker.reset
      @circuit = Circuitbox::CircuitBreaker.new(:yammer,
                                                sleep_window: 300,
                                                volume_threshold: 5,
                                                error_threshold: 33,
                                                timeout_seconds: 1)
    end

    def test_open_circuit_on_100_percent_failure
      run_counter = 0
      10.times do
        @circuit.run do
          run_counter += 1
          raise Timeout::Error
        end
      end
      assert_equal 6, run_counter, 'the circuit did not open after 6 failures (5 failures + 10%)'
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
      @circuit.run { 'success'}
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

  class Exceptions < Minitest::Test
    class SentinalError < StandardError; end

    def setup
      Circuitbox::CircuitBreaker.reset
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
  end

  class CloseAfterSleep < Minitest::Test
    def setup
      Circuitbox::CircuitBreaker.reset
      @circuit = Circuitbox::CircuitBreaker.new(:yammer,
                                                sleep_window: 1,
                                                time_window: 2,
                                                volume_threshold: 5,
                                                error_threshold: 5,
                                                timeout_seconds: 1)
    end

    def test_circuit_closes_after_sleep_time_window
      open_circuit!
      run_count = 0
      @circuit.run { run_count += 1 }
      assert_equal 0, run_count, 'circuit has not opened prior'
      # it is + 2 on purpose, because + 1 is flaky here
      sleep @circuit.option_value(:sleep_window) + 2

      @circuit.run { run_count += 1 }
      assert_equal 1, run_count, 'circuit did not close after sleep'
    end

    def open_circuit!
      (@circuit.option_value(:error_threshold) + 1).times { @circuit.run { raise Timeout::Error } }
    end
  end

  class HalfOpenState < Minitest::Test
    def setup
      Circuitbox::CircuitBreaker.reset
      @circuit = Circuitbox::CircuitBreaker.new(:yammer)
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

  def test_should_use_timeout_class_if_exceptions_are_not_defined
    circuit = Circuitbox::CircuitBreaker.new(:yammer, timeout_seconds: 45)
    circuit.expects(:timeout).with(45).once
    emulate_circuit_run(circuit, :success, StandardError)
  end

  def test_should_not_use_timeout_class_if_custom_exceptions_are_defined
    circuit = Circuitbox::CircuitBreaker.new(:yammer, exceptions: [ConnectionError])
    circuit.expects(:timeout).never
    emulate_circuit_run(circuit, :success, StandardError)
  end

  def test_should_return_response_if_it_doesnt_timeout
    circuit = Circuitbox::CircuitBreaker.new(:yammer)
    response = emulate_circuit_run(circuit, :success, "success")
    assert_equal "success", response
  end

  def test_timeout_seconds_run_options_overrides_circuit_options
    circuit = Circuitbox::CircuitBreaker.new(:yammer, timeout_seconds: 60)
    circuit.expects(:timeout).with(30).once
    circuit.run(timeout_seconds: 30) { true }
  end

  def test_catches_connection_error_failures_if_defined
    circuit = Circuitbox::CircuitBreaker.new(:yammer, :exceptions => [ConnectionError])
    response = emulate_circuit_run(circuit, :failure, ConnectionError)
    assert_equal nil, response
  end

  def test_doesnt_catch_out_of_scope_exceptions
    sentinal = Class.new(StandardError)
    circuit = Circuitbox::CircuitBreaker.new(:yammer, :exceptions => [ConnectionError, Timeout::Error])

    assert_raises(sentinal) do
      emulate_circuit_run(circuit, :failure, sentinal)
    end
  end

  def test_records_response_failure
    circuit = Circuitbox::CircuitBreaker.new(:yammer, :exceptions => [Timeout::Error])
    circuit.expects(:log_event).with(:failure)
    emulate_circuit_run(circuit, :failure, Timeout::Error)
  end

  def test_records_response_skipped
    circuit = Circuitbox::CircuitBreaker.new(:yammer)
    circuit.stubs(:open? => true)
    circuit.stubs(:log_event)
    circuit.expects(:log_event).with(:skipped)
    emulate_circuit_run(circuit, :failure, Timeout::Error)
  end

  def test_records_response_success
    circuit = Circuitbox::CircuitBreaker.new(:yammer)
    circuit.expects(:log_event).with(:success)
    emulate_circuit_run(circuit, :success, "success")
  end

  def test_does_not_send_request_if_circuit_is_open
    circuit = Circuitbox::CircuitBreaker.new(:yammer)
    circuit.stubs(:open? => true)
    circuit.expects(:yield).never
    response = emulate_circuit_run(circuit, :failure, Timeout::Error)
    assert_equal nil, response
  end

  def test_returns_nil_response_on_failed_request
    circuit = Circuitbox::CircuitBreaker.new(:yammer)
    response = emulate_circuit_run(circuit, :failure, Timeout::Error)
    assert_equal nil, response
  end

  def test_puts_circuit_to_sleep_once_opened
    circuit = Circuitbox::CircuitBreaker.new(:yammer)
    circuit.stubs(:open? => true)

    assert !circuit.send(:open_flag?)
    emulate_circuit_run(circuit, :failure, Timeout::Error)
    assert circuit.send(:open_flag?)

    circuit.expects(:open!).never
    emulate_circuit_run(circuit, :failure, Timeout::Error)
  end

  def test_open_is_true_if_open_flag
    circuit = Circuitbox::CircuitBreaker.new(:yammer)
    circuit.stubs(:open_flag? => true)
    assert circuit.open?
  end

  def test_open_checks_if_volume_threshold_has_passed
    circuit = Circuitbox::CircuitBreaker.new(:yammer)
    circuit.stubs(:open_flag? => false)

    circuit.expects(:passed_volume_threshold?).once
    circuit.open?
  end

  def test_open_checks_error_rate_threshold
    circuit = Circuitbox::CircuitBreaker.new(:yammer)
    circuit.stubs(:open_flag? => false,
                  :passed_volume_threshold? => true)

    circuit.expects(:passed_rate_threshold?).once
    circuit.open?
  end

  def test_open_is_false_if_awake_and_under_rate_threshold
    circuit = Circuitbox::CircuitBreaker.new(:yammer)
    circuit.stubs(:open_flag? => false,
                  :passed_volume_threshold? => false,
                  :passed_rate_threshold => false)

    assert !circuit.open?
  end

  def test_error_rate_threshold_calculation
    circuit = Circuitbox::CircuitBreaker.new(:yammer)
    circuit.stubs(:failure_count => 3, :success_count => 2)
    assert circuit.send(:passed_rate_threshold?)

    circuit.stubs(:failure_count => 2, :success_count => 3)
    assert !circuit.send(:passed_rate_threshold?)
  end

  def test_logs_and_retrieves_success_events
    circuit = Circuitbox::CircuitBreaker.new(:yammer)
    5.times { circuit.send(:log_event, :success) }
    assert_equal 5, circuit.send(:success_count)
  end

  def test_logs_and_retrieves_failure_events
    circuit = Circuitbox::CircuitBreaker.new(:yammer)
    5.times { circuit.send(:log_event, :failure) }
    assert_equal 5, circuit.send(:failure_count)
  end

  def test_logs_events_by_minute
    circuit = Circuitbox::CircuitBreaker.new(:yammer)

    Timecop.travel(Time.now.change(sec: 5))
    4.times { circuit.send(:log_event, :success) }
    assert_equal 4, circuit.send(:success_count)

    Timecop.travel(1.minute.from_now)
    7.times { circuit.send(:log_event, :success) }
    assert_equal 7, circuit.send(:success_count)

    Timecop.travel(30.seconds.from_now)
    circuit.send(:log_event, :success)
    assert_equal 8, circuit.send(:success_count)

    Timecop.travel(50.seconds.from_now)
    assert_equal 0, circuit.send(:success_count)
  end

  class Notifications < Minitest::Test
    def setup
      Circuitbox::CircuitBreaker.reset
    end

    def test_notification_on_open
      notifier = gimme_notifier
      circuit = Circuitbox::CircuitBreaker.new(:yammer, notifier_class: notifier)
      10.times { circuit.run { raise Timeout::Error }}
      assert notifier.notified?, 'no notification sent'
    end

    def test_notification_on_close
      notifier = gimme_notifier
      circuit = Circuitbox::CircuitBreaker.new(:yammer, notifier_class: notifier)
      5.times { circuit.run { raise Timeout::Error }}
      notifier.clear_notified!
      10.times { circuit.run { 'success' }}
      assert notifier.notified?, 'no notification sent'
    end

    def test_warning_when_sleep_window_is_shorter_than_time_window
      notifier = gimme_notifier
      Circuitbox::CircuitBreaker.new(:yammer,
                                     notifier_class: notifier,
                                     sleep_window: 1,
                                     time_window: 10)
      assert notifier.notified?, 'no notification sent'
    end

    def test_does_not_warn_on_sleep_window_being_correctly_sized
      notifier = gimme_notifier
      Circuitbox::CircuitBreaker.new(:yammer,
                                     notifier_class: notifier,
                                     sleep_window: 11,
                                     time_window: 10)
      assert_equal false, notifier.notified?, 'no notification sent'
    end

    def test_notifies_on_success_rate_calculation
      notifier = gimme_notifier(metric: :error_rate, metric_value: 0.0)
      circuit = Circuitbox::CircuitBreaker.new(:yammer, notifier_class: notifier)
      10.times { circuit.run { "success" } }
      assert notifier.notified?, "no notification sent"
    end

    def test_notifies_on_error_rate_calculation
      notifier = gimme_notifier(metric: :failure_count, metric_value: 1)
      circuit = Circuitbox::CircuitBreaker.new(:yammer, notifier_class: notifier)
      10.times { circuit.run { raise Timeout::Error  }}
      assert notifier.notified?, 'no notification sent'
    end

    def test_success_count_on_error_rate_calculation
      notifier = gimme_notifier(metric: :success_count, metric_value: 6)
      circuit = Circuitbox::CircuitBreaker.new(:yammer, notifier_class: notifier)
      10.times { circuit.run { 'success' }}
      assert notifier.notified?, 'no notification sent'
    end

    def test_send_execution_time_metric
      notifier = gimme_notifier(metric: :execution_time, metric_value: Gimme::Matchers::Anything.new)
      circuit = Circuitbox::CircuitBreaker.new(:yammer, notifier_class: notifier)
      circuit.run { 'success' }
      assert notifier.metric_sent?, 'no execution time metric sent'
    end

    def test_no_execution_time_metric_on_error_execution
      notifier = gimme_notifier(metric: :execution_time, metric_value: Gimme::Matchers::Anything.new)
      circuit = Circuitbox::CircuitBreaker.new(:yammer, notifier_class: notifier)
      circuit.run { raise Timeout::Error }
      refute notifier.metric_sent?, 'execution time metric sent'
    end

    def test_no_execution_time_metric_when_circuit_open
      notifier = gimme_notifier(metric: :execution_time, metric_value: Gimme::Matchers::Anything.new)
      circuit = Circuitbox::CircuitBreaker.new(:yammer, notifier_class: notifier)
      circuit.send(:open!)
      circuit.run { raise Timeout::Error }
      refute notifier.metric_sent?, 'execution time metric sent'
    end

    def gimme_notifier(opts={})
      metric = opts.fetch(:metric,:error_rate)
      metric_value = opts.fetch(:metric_value, 0.0)
      warning_msg = opts.fetch(:warning_msg, '')
      fake_notifier = gimme
      notified = false
      metric_sent = false
      give(fake_notifier).notify(:open) { notified = true }
      give(fake_notifier).notify(:close) { notified = true }
      give(fake_notifier).notify_warning(Gimme::Matchers::Anything.new) { notified = true }
      give(fake_notifier).metric_gauge(metric, metric_value) do
        notified = true
        metric_sent = true
      end
      fake_notifier_class = gimme
      give(fake_notifier_class).new(:yammer) { fake_notifier }
      give(fake_notifier_class).notified? { notified }
      give(fake_notifier_class).metric_sent? { metric_sent }
      give(fake_notifier_class).clear_notified! { notified = false }
      fake_notifier_class
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
