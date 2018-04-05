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
    Circuitbox.default_timer = nil
  end

  def test_configure_block_clears_cached_circuits
    Circuitbox.expects(:clear_cached_circuits!)
    Circuitbox.configure {}
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

  def test_default_timer_is_configurable
    timer = gimme
    Circuitbox.default_timer = timer
    assert_equal timer, Circuitbox.default_timer
  end

  def test_delegates_to_circuit
    Circuitbox.expects(:circuit).with(:yammer, {})
    Circuitbox[:yammer]
  end

  def test_creates_a_circuit_breaker
    assert Circuitbox[:yammer].is_a? Circuitbox::CircuitBreaker
  end

  def test_returns_the_same_circuit_every_time
    assert_equal Circuitbox.circuit(:yammer), Circuitbox.circuit(:yammer)
  end

  def test_sets_the_circuit_options_the_first_time_only
    circuit_one = Circuitbox.circuit(:yammer, sleep_window: 1337)
    circuit_two = Circuitbox.circuit(:yammer, sleep_window: 2000)

    assert_equal 1337, circuit_one.option_value(:sleep_window)
    assert_equal 1337, circuit_two.option_value(:sleep_window)
  end
end
