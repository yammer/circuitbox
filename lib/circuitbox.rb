# frozen_string_literal: true

require 'logger'

require_relative 'circuitbox/version'
require_relative 'circuitbox/circuit_breaker'
require_relative 'circuitbox/errors/error'
require_relative 'circuitbox/errors/open_circuit_error'
require_relative 'circuitbox/errors/service_failure_error'
require_relative 'circuitbox/configuration'

class Circuitbox
  extend Configuration

  class << self
    def circuit(service_name, options, &block)
      circuit = find_or_create_circuit_breaker(service_name, options)

      return circuit unless block

      circuit.run(circuitbox_exceptions: false, &block)
    end
  end
end
