require 'test_helper'

class CircuitboxTest < Minitest::Test

  def setup
    Circuitbox.reset
  end

  def test_circuit_store_is_configurable
    store = Moneta.new(:Memory, expires: true)
    Circuitbox.circuit_store = store
    assert_equal store, Circuitbox[:yammer].circuit_store
  end

  def test_default_notifier_is_configurable
    notifier = gimme
    Circuitbox.default_notifier = notifier
    assert_equal notifier, Circuitbox.default_notifier
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
    circuit_one = Circuitbox.circuit(:yammer, :sleep_window => 1337)
    circuit_two = Circuitbox.circuit(:yammer, :sleep_window => 2000)

    assert_equal 1337, circuit_one.option_value(:sleep_window)
    assert_equal 1337, circuit_two.option_value(:sleep_window)
  end

  def test_uses_parsed_uri_host_as_identifier_for_circuit
    service = Circuitbox.parameter_to_service_name("http://api.yammer.com/api/v1/messages")
    assert_equal "api.yammer.com", service
  end

  def test_uses_identifier_directly_for_circuit_if_it_is_not_an_uri
    service = Circuitbox.parameter_to_service_name(:yammer)
    assert_equal "yammer", service
  end
end
