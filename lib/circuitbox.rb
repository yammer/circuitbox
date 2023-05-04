# frozen_string_literal: true

require_relative 'circuitbox/version'
require_relative 'circuitbox/circuit_breaker'
require_relative 'circuitbox/errors/error'
require_relative 'circuitbox/errors/open_circuit_error'
require_relative 'circuitbox/errors/service_failure_error'
require_relative 'circuitbox/configuration'

class Circuitbox
  extend Configuration

  class << self
    # @overload circuit(service_name, options = {})
    #   Returns a Circuitbox::CircuitBreaker for the given service_name
    #
    #   @param service_name [String, Symbol] Name of the service
    #     Mixing Symbols/Strings for the same service (:test/'test') will result in
    #     multiple circuits being created that point to the same service.
    #   @param options [Hash] Options for the circuit (See Circuitbox::CircuitBreaker#initialize options)
    #     Any configuration options should always be passed when calling this method.
    #   @return [Circuitbox::CircuitBreaker] CircuitBreaker for the given service_name
    #
    # @overload circuit(service_name, options = {}, &block)
    #   Runs the circuit with the given block
    #   The circuit's run method is called with `exception` set to false
    #
    #   @param service_name [String, Symbol] Name of the service
    #     Mixing Symbols/Strings for the same service (:test/'test') will result in
    #     multiple circuits being created that point to the same service.
    #   @param options [Hash] Options for the circuit (See Circuitbox::CircuitBreaker#initialize options)
    #     Any configuration options should always be passed when calling this method.
    #
    #   @return [Object] The result of the block
    #   @return [nil] If the circuit is open
    def circuit(service_name, options, &block)
      circuit = find_or_create_circuit_breaker(service_name, options)

      return circuit unless block

      circuit.run(exception: false, &block)
    end
  end
end
