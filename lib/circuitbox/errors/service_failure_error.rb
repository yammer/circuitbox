class Circuitbox
  class ServiceFailureError < Circuitbox::Error
    attr_reader :service, :original

    def initialize(service, exception)
      @service = service
      @original = exception
    end

    def to_s
      "#{self.class.name} wrapped: #{original}"
    end

  end
end
