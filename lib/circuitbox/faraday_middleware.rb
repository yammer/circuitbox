require 'faraday'
require 'circuitbox'

class Circuitbox
  class FaradayMiddleware < Faraday::Middleware
    class RequestFailed < StandardError; end

    class NullResponse < Faraday::Response
      attr_reader :original_response, :original_exception
      def initialize(response = nil, exception = nil)
        @original_response  = response
        @original_exception = exception
        super(status: 503, response_headers: {})
      end
    end

    DEFAULT_OPTIONS = {
      open_circuit: lambda do |response|
        # response.status:
        # nil -> connection could not be established, or failed very hard
        # 5xx -> non recoverable server error, oposed to 4xx which are client errors
        response.status.nil? || (response.status >= 500 && response.status <= 599)
      end,
      default_value: ->(service_response, exception) { NullResponse.new(service_response, exception) },
      # It's possible for the URL object to not have a host at the time the middleware
      # is run. To not break circuitbox by creating a circuit with a nil service name
      # we can get the string representation of the URL object and use that as the service name.
      identifier: ->(env) { env[:url].host || env[:url].to_s },
      # default circuit breaker options are merged in during initialization
      circuit_breaker_options: {}
    }.freeze

    DEFAULT_EXCEPTIONS = [
      Faraday::TimeoutError,
      RequestFailed
    ].freeze

    DEFAULT_CIRCUIT_BREAKER_OPTIONS = {
      exceptions: DEFAULT_EXCEPTIONS
    }.freeze

    attr_reader :opts

    def initialize(app, opts = {})
      @app = app
      @opts = DEFAULT_OPTIONS.merge(opts)

      @opts[:circuit_breaker_options] = DEFAULT_CIRCUIT_BREAKER_OPTIONS.merge(@opts[:circuit_breaker_options])
      super(app)
    end

    def call(request_env)
      service_response = nil
      circuit(request_env).run do
        @app.call(request_env).on_complete do |env|
          service_response = Faraday::Response.new(env)
          raise RequestFailed if open_circuit?(service_response)
        end
      end
    rescue Circuitbox::Error => ex
      circuit_open_value(request_env, service_response, ex)
    end

    private

    def call_default_value(response, exception)
      default_value = opts[:default_value]
      default_value.respond_to?(:call) ? default_value.call(response, exception) : default_value
    end

    def open_circuit?(response)
      opts[:open_circuit].call(response)
    end

    def circuit_open_value(env, service_response, exception)
      env[:circuit_breaker_default_value] || call_default_value(service_response, exception)
    end

    def circuit(env)
      identifier = opts[:identifier]
      id = identifier.respond_to?(:call) ? identifier.call(env) : identifier

      Circuitbox.circuit(id, opts[:circuit_breaker_options])
    end
  end
end

Faraday::Middleware.register_middleware circuitbox: Circuitbox::FaradayMiddleware
