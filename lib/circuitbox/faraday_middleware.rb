require 'faraday'
require 'circuitbox'

class Circuitbox
  class FaradayMiddleware < Faraday::Middleware
    class RequestFailed < StandardError; end

    DEFAULT_EXCEPTIONS = [
      Faraday::Error::TimeoutError,
      RequestFailed
    ].freeze

    class NullResponse < Faraday::Response
      attr_reader :original_response, :original_exception
      def initialize(response = nil, exception = nil)
        @original_response  = response
        @original_exception = exception
        super(status: 503, response_headers: {})
      end
    end

    attr_reader :opts

    DEFAULT_CIRCUITBOX_OPTIONS = {
      open_circuit: lambda do |response|
        # response.status:
        # nil -> connection could not be established, or failed very hard
        # 5xx -> non recoverable server error, oposed to 4xx which are client errors
        response.status.nil? || (500 <= response.status && response.status <= 599)
      end,
      default_value: ->(service_response, exception) { NullResponse.new(service_response, exception) }
    }

    def initialize(app, opts = {})
      @app = app
      @opts = DEFAULT_CIRCUITBOX_OPTIONS.merge(opts)
      super(app)
    end

    def call(request_env)
      service_response = nil
      circuit(request_env).run! do
        @app.call(request_env).on_complete do |env|
          service_response = Faraday::Response.new(env)
          raise RequestFailed if open_circuit?(service_response)
        end
      end
    rescue Circuitbox::Error => ex
      circuit_open_value(request_env, service_response, ex)
    end

    def exceptions
      circuit_breaker_options[:exceptions]
    end

    def identifier
      # It's possible for the URL object to not have a host at the time the middleware
      # is run. To not break circuitbox by creating a circuit with a nil service name
      # we can get the string representation of the URL object and use that as the service name.
      @identifier ||= opts.fetch(:identifier, ->(env) { env[:url].host || env[:url].to_s })
    end

    private

    def circuit_breaker_options
      @circuit_breaker_options ||= begin
        options = opts.fetch(:circuit_breaker_options, {})
        options.merge!(
          exceptions: opts.fetch(:exceptions, DEFAULT_EXCEPTIONS)
        )
      end
    end

    def call_default_value(response, exception)
      default_value = opts[:default_value]
      default_value.respond_to?(:call) ? default_value.call(response, exception) : default_value
    end

    def open_circuit?(response)
      opts[:open_circuit].call(response)
    end

    def circuitbox
      @circuitbox ||= opts.fetch(:circuitbox, Circuitbox)
    end

    def circuit_open_value(env, service_response, exception)
      env[:circuit_breaker_default_value] || call_default_value(service_response, exception)
    end

    def circuit(env)
      id = identifier.respond_to?(:call) ? identifier.call(env) : identifier
      circuitbox.circuit(id, circuit_breaker_options)
    end
  end
end

Faraday::Middleware.register_middleware circuitbox: Circuitbox::FaradayMiddleware
