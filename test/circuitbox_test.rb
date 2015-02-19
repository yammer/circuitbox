require 'test_helper'

class Circuitbox::ExampleStore < ActiveSupport::Cache::MemoryStore; end

describe Circuitbox do
  before { Circuitbox.reset }
  after { Circuitbox.reset }

  describe "Circuitbox.configure" do
    it "configures instance variables on init" do
      Circuitbox.configure do
        self.stat_store = "hello"
      end

      assert_equal "hello", Circuitbox.stat_store
    end
  end

  describe "Circuitbox.circuit_store" do
    it "is configurable" do
      example_store = Circuitbox::ExampleStore.new
      Circuitbox.circuit_store = example_store
      assert_equal example_store, Circuitbox[:yammer].circuit_store
    end
  end

  describe "Circuitbox.stat_store" do
    it "is configurable" do
      example_store = Circuitbox::ExampleStore.new
      Circuitbox.stat_store = example_store
      assert_equal example_store, Circuitbox[:yammer].stat_store
    end
  end

  describe "Circuitbox[:service]" do
    it "delegates to #circuit" do
      Circuitbox.expects(:circuit).with(:yammer, {})
      Circuitbox[:yammer]
    end

    it "creates a CircuitBreaker instance" do
      assert Circuitbox[:yammer].is_a? Circuitbox::CircuitBreaker
    end
  end

  describe "#circuit" do
    it "returns the same circuit every time" do
      assert_equal Circuitbox.circuit(:yammer).object_id, Circuitbox.circuit(:yammer).object_id
    end

    it "sets the circuit options the first time" do
      circuit_one = Circuitbox.circuit(:yammer, :sleep_window => 1337)
      circuit_two = Circuitbox.circuit(:yammer, :sleep_window => 2000)

      assert_equal 1337, circuit_one.option_value(:sleep_window)
      assert_equal 1337, circuit_two.option_value(:sleep_window)
    end
  end

  describe "#parameter_to_service_name" do
    it "parses out a service name from URI" do
      service = Circuitbox.parameter_to_service_name("http://api.yammer.com/api/v1/messages")
      assert_equal "api.yammer.com", service
    end

    it "uses the parameter as the service name if the parameter is not an URI" do
      service = Circuitbox.parameter_to_service_name(:yammer)
      assert_equal "yammer", service
    end
  end

end
