# frozen_string_literal: true

class Circuitbox
  class OpenCircuitError < Circuitbox::Error
    attr_reader :service

    def initialize(service)
      super()
      @service = service
    end

    def to_s
      "#{self.class}: Service #{service.inspect} has an open circuit"
    end
  end
end
