# frozen_string_literal: true

class Circuitbox
  class OpenCircuitError < Circuitbox::Error
    attr_reader :service

    def initialize(service)
      super()
      @service = service
    end
  end
end
