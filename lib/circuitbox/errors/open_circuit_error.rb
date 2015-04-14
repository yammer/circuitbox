class Circuitbox
  class OpenCircuitError < Circuitbox::Error
    attr_reader :service

    def initialize(service)
      @service = service
    end

  end
end
