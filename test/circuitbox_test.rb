# frozen_string_literal: true

require 'test_helper'

class CircuitboxTest < Minitest::Test
  def setup
    Circuitbox.send(:clear_cached_circuits!)
  end

  def teardown
    Circuitbox.default_notifier = nil
    Circuitbox.default_logger = nil
    Circuitbox.default_circuit_store = nil
  end

  def test_configure_block_clears_cached_circuits
    Circuitbox.expects(:clear_cached_circuits!)
    Circuitbox.configure { 'no config' }
  end

  def test_default_circuit_store_is_configurable
    store = gimme
    Circuitbox.default_circuit_store = store
    assert_equal store, Circuitbox.default_circuit_store
  end

  def test_default_notifier_is_configurable
    notifier = gimme
    Circuitbox.default_notifier = notifier
    assert_equal notifier, Circuitbox.default_notifier
  end

  def test_default_logger_is_configurable
    logger = gimme
    Circuitbox.default_logger = logger
    assert_equal logger, Circuitbox.default_logger
  end

  def test_creates_a_circuit_breaker
    assert Circuitbox.circuit(:yammer, exceptions: [Timeout::Error]).is_a? Circuitbox::CircuitBreaker
  end

  def test_returns_the_same_circuit_every_time
    assert_equal Circuitbox.circuit(:yammer, exceptions: [Timeout::Error]),
                 Circuitbox.circuit(:yammer, exceptions: [Timeout::Error])
  end

  def test_sets_the_circuit_options_the_first_time_only
    circuit_one = Circuitbox.circuit(:yammer, exceptions: [Timeout::Error], sleep_window: 1337)
    circuit_two = Circuitbox.circuit(:yammer, exceptions: [StandardError], sleep_window: 2000)

    assert_equal 1337, circuit_one.option_value(:sleep_window)
    assert_equal 1337, circuit_two.option_value(:sleep_window)
    assert_equal [Timeout::Error], circuit_two.exceptions
  end

  def test_run_sets_circuit_exceptions_to_false
    Circuitbox::CircuitBreaker.any_instance.expects(:run).with(exception: false)

    Circuitbox.circuit(:yammer, exceptions: [Timeout::Error]) { 'success' }
  end
end
