# frozen_string_literal: true

class Circuitbox
  class OpenCircuitError < Circuitbox::Error
    attr_reader :service

    def initialize(service)
      super("Service #{service.inspect} has an open circuit")
      @service = service
    end
  end
end
