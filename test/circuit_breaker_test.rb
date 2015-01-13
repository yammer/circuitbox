require 'test_helper'
require 'ostruct'

class CircuitBreakerTest < Minitest::Test
  SUCCESSFUL_RESPONSE_STRING = "Success!"
  RequestFailureError = Timeout::Error
  class ConnectionError < StandardError; end;
  class SomeOtherError < StandardError; end;

  def setup
    Circuitbox::CircuitBreaker.reset
  end

  describe 'initialize' do
    it 'force sleep_window to equal time_window if it is too short' do
      circuit = Circuitbox::CircuitBreaker.new(:yammer,
                                     :sleep_window   =>  1,
                                     :time_window    => 10
                                    )
      assert_equal circuit.option_value(:sleep_window),
        circuit.option_value(:time_window),
        'sleep_window has not been corrected properly'
    end
  end

  def test_goes_into_half_open_state_on_sleep
    circuit = Circuitbox::CircuitBreaker.new(:yammer)
    circuit.send(:open!)
    assert circuit.send(:half_open?)
  end


  describe 'ratio' do
    def cb_options
      {
        sleep_window:     300,
        volume_threshold: 5,
        error_threshold:  33,
        timeout_seconds:  1
      }
    end

    def setup
      Circuitbox::CircuitBreaker.reset
      @circuit = Circuitbox::CircuitBreaker.new(:yammer, cb_options)
    end


    it 'open the circuit on 100% failure' do
      run_counter = 0
      10.times do
        @circuit.run do
          run_counter += 1
          raise RequestFailureError
        end
      end
      assert_equal 6, run_counter, 'the circuit did not open after 6 failures (5 failures + 10%)'
    end

    it 'keep circuit closed on 0% failure' do
      run_counter = 0
      10.times do
        @circuit.run do
          run_counter += 1
          'sucess'
        end
      end
      assert_equal 10, run_counter, 'run block was not executed 10 times'
    end

    it 'open the circuit even after 1 success' do
      run_counter = 0
      5.times do
        @circuit.run do
          run_counter += 1
          raise RequestFailureError
        end
      end

      # one success
      @circuit.run { 'success'}
      assert_equal 5, @circuit.failure_count, 'the total count of failures is not 5'

      5.times do
        @circuit.run do
          run_counter += 1
          raise RequestFailureError
        end
      end
      assert_equal 5, run_counter, 'the circuit did not open after 5 failures (5 failures + 10%)'
    end

    it 'keep circuit closed when failure ratio do not exceed limit' do
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
          raise RequestFailureError
        end
      end
      assert_equal 10, run_counter, 'block was not executed 10 times'
      assert @circuit.error_rate < 33, 'error_rate pass over 33%'
    end

    it 'circuit open when failure ratio exceed limit' do
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
          raise RequestFailureError
        end
      end
      # 5 failure on 15 run is 33%
      assert_equal 15, run_counter, 'block was not executed 10 times'
      assert @circuit.error_rate >= 33, 'error_rate pass over 33%'
    end

  end

  describe 'closing the circuit after sleep' do
    class GodTime < SimpleDelegator
      def now
        self
      end

      def initialize(now=nil)
        @now = now || Time.now
        super(@now)
      end

      def __getobj__
        @now
      end

      def __setobj__(obj)
        @now = obj
      end

      def jump(interval)
        __setobj__ @now + interval
      end
    end

    def cb_options
      {
        sleep_window:     70,
        time_window:      60,
        volume_threshold: 5,
        error_threshold:  33,
        timeout_seconds:  1,
        time_class: @timer
      }
    end

    def setup
      @timer   = GodTime.new
      @circuit = Circuitbox::CircuitBreaker.new(:yammer, cb_options)
    end


    it 'close the circuit after sleeping time' do
      # lets open the circuit
      10.times { @circuit.run { raise RequestFailureError } }
      run_count = 0
      @circuit.run { run_count += 1 }
      assert_equal 0, run_count, 'circuit is not open'

      @timer.jump(cb_options[:sleep_window] + 1)
      @circuit.try_close_next_time
      @circuit.run { run_count += 1 }
      assert_equal 1, run_count, 'circuit is not closed'
    end
  end

  describe "when in half open state" do
    before do
      Circuitbox::CircuitBreaker.reset
      @circuit = Circuitbox::CircuitBreaker.new(:yammer)
    end

    it "opens circuit on next failed request" do
      @circuit.stubs(half_open?: true)
      @circuit.expects(:open!)
      @circuit.run { raise RequestFailureError }
    end

    it "closes circuit on successful request" do
      @circuit.send(:half_open!)
      @circuit.run { 'success' }
      assert !@circuit.send(:half_open?)
      assert !@circuit.send(:open?)
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
    response = emulate_circuit_run(circuit, :success, SUCCESSFUL_RESPONSE_STRING)
    assert_equal SUCCESSFUL_RESPONSE_STRING, response
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
    circuit = Circuitbox::CircuitBreaker.new(:yammer, :exceptions => [ConnectionError, RequestFailureError])

    assert_raises SomeOtherError do
      emulate_circuit_run(circuit, :failure, SomeOtherError)
    end
  end

  def test_records_response_failure
    circuit = Circuitbox::CircuitBreaker.new(:yammer, :exceptions => [RequestFailureError])
    circuit.expects(:log_event).with(:failure)
    emulate_circuit_run(circuit, :failure, RequestFailureError)
  end

  def test_records_response_success
    circuit = Circuitbox::CircuitBreaker.new(:yammer)
    circuit.expects(:log_event).with(:success)
    emulate_circuit_run(circuit, :success, SUCCESSFUL_RESPONSE_STRING)
  end

  def test_does_not_send_request_if_circuit_is_open
    circuit = Circuitbox::CircuitBreaker.new(:yammer)
    circuit.stubs(:open? => true)
    circuit.expects(:yield).never
    response = emulate_circuit_run(circuit, :failure, RequestFailureError)
    assert_equal nil, response
  end

  def test_returns_nil_response_on_failed_request
    circuit = Circuitbox::CircuitBreaker.new(:yammer)
    response = emulate_circuit_run(circuit, :failure, RequestFailureError)
    assert_equal nil, response
  end

  def test_puts_circuit_to_sleep_once_opened
    circuit = Circuitbox::CircuitBreaker.new(:yammer)
    circuit.stubs(:open? => true)

    assert !circuit.send(:open_flag?)
    emulate_circuit_run(circuit, :failure, RequestFailureError)
    assert circuit.send(:open_flag?)

    circuit.expects(:open!).never
    emulate_circuit_run(circuit, :failure, RequestFailureError)
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

  describe 'notifications' do

    def setup
      Circuitbox::CircuitBreaker.reset
    end

    def circuit
      Circuitbox::CircuitBreaker.new(:yammer, :notifier_class => @notifier)
    end


    it 'notifies on open circuit' do
      @notifier = gimme_notifier
      c = circuit
      10.times { c.run { raise RequestFailureError }}
      assert @notifier.notified?, 'no notification sent'
    end

    it 'notifies on close circuit' do
      @notifier = gimme_notifier
      c = circuit
      5.times { c.run { raise RequestFailureError }}
      clear_notified!
      10.times { c.run { 'success' }}
      assert @notifier.notified?, 'no notification sent'
    end

    it 'notifies warning if sleep_window is shorter than time_window' do
      @notifier = gimme_notifier
      Circuitbox::CircuitBreaker.new(:yammer,
                                     :notifier_class => @notifier,
                                     :sleep_window   =>  1,
                                     :time_window    => 10
                                    )
      assert @notifier.notified?, 'no notification sent'
    end

    it 'DO NOT notifies warning if sleep_window is longer than time_window' do
      @notifier = gimme_notifier
      Circuitbox::CircuitBreaker.new(:yammer,
                                     :notifier_class => @notifier,
                                     :sleep_window   => 11,
                                     :time_window    => 10
                                    )
      assert_equal false, @notifier.notified?, 'no notification sent'
    end


    it 'notifies error_rate on error_rate calculation' do
      @notifier = gimme_notifier(metric: :error_rate, metric_value: 0.0)
      10.times { circuit.run {'success' }}
      assert @notifier.notified?, 'no notification sent'
    end

    it 'notifies failure_count on error_rate calculation' do
      @notifier = gimme_notifier(metric: :failure_count, metric_value: 1)
      10.times { circuit.run { raise RequestFailureError  }}
      assert @notifier.notified?, 'no notification sent'
    end

    it 'notifies success_count on error_rate calculation' do
      @notifier = gimme_notifier(metric: :success_count, metric_value: 6)
      10.times { circuit.run { 'success' }}
      assert @notifier.notified?, 'no notification sent'
    end

    def clear_notified!
      @notified = false
    end

    def gimme_notifier(opts={})
      clear_notified!
      metric       = opts.fetch(:metric,:error_rate)
      metric_value = opts.fetch(:metric_value, 0.0)
      warning_msg  = opts.fetch(:warning_msg, '')
      fake_notifier = gimme
      give(fake_notifier).notify(:open) { @notified=true }
      give(fake_notifier).notify(:close) { @notified=true }
      give(fake_notifier).notify_warning(Gimme::Matchers::Anything.new) { @notified = true }
      give(fake_notifier).metric_gauge(metric, metric_value) { @notified=true }
      fake_notifier_class = gimme
      give(fake_notifier_class).new(:yammer,nil) { fake_notifier }
      give(fake_notifier_class).notified? { @notified }
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
  rescue RequestFailureError
    nil
  end
end
