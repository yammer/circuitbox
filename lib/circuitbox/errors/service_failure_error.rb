class Circuitbox
  class ServiceFailureError < Circuitbox::Error
    attr_reader :service, :original

    def initialize(service, exception)
      @service = service
      @original = exception
    end

  end
end
