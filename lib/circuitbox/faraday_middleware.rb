require 'faraday'
require 'circuitbox'

class Circuitbox
  class RequestError < StandardError; end

  class FaradayMiddleware < Faraday::Response::Middleware

    attr_accessor :identifier, :exceptions

    def initialize(app, opts={})
      @identifier = opts.fetch(:identifier) { ->(env) { env.url }}
      @exceptions = opts.fetch(:exceptions) { [Faraday::Error::TimeoutError] }
      super(app)
    end

    def call(env)
      id = identifier.respond_to?(:call) ? identifier.call(env) : identifier
      circuit = Circuitbox.circuit id, :exceptions => exceptions
      circuit.run do
        super(env)
      end
    end

    def on_complete(env)
      if !env.success?
        raise RequestError
      end
    end
  end
end
