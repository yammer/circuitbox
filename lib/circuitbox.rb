require 'uri'
require 'logger'
require 'timeout'
require 'active_support/all'

require_relative 'circuitbox/version'
require_relative 'circuitbox/circuit_breaker'
require_relative 'circuitbox/errors/error'
require_relative 'circuitbox/errors/open_circuit_error'
require_relative 'circuitbox/errors/service_failure_error'
require_relative 'circuitbox/configuration'

class Circuitbox
  class << self
    include Configuration

    def [](service_name, options = {})
      circuit(service_name, options)
    end

    def circuit(service_name, options = {})
      circuit = (cached_circuits[service_name] ||= CircuitBreaker.new(service_name, options))

      return circuit unless block_given?

      circuit.run { yield }
    end
  end
end
