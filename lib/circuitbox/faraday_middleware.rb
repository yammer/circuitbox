require 'faraday'
require 'circuitbox'

class Circuitbox
  class FaradayMiddleware < Faraday::Middleware
    class RequestFailed < StandardError; end

    DEFAULT_EXCEPTIONS = [
      Faraday::Error::TimeoutError,
      RequestFailed,
    ]

    class NullResponse < Faraday::Response
      attr_reader :original_response, :original_exception
      def initialize(response = nil, exception = nil)
        @original_response  = response
        @original_exception = exception
        super(status: 503, response_headers: {})
      end
    end

    attr_reader :opts

    def initialize(app, opts = {})
      @app = app
      default_options = { open_circuit: lambda { |response| !response.success? } }
      @opts = default_options.merge(opts)
      super(app)
    end

    def call(request_env)
      service_response = nil
      circuit(request_env).run!(run_options(request_env)) do
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
      @identifier ||= opts.fetch(:identifier, ->(env) { env[:url] })
    end

    private

    def run_options(env)
      env[:circuit_breaker_run_options] || {}
    end

    def circuit_breaker_options
      return @circuit_breaker_options if @current_adapter

      @circuit_breaker_options = opts.fetch(:circuit_breaker_options, {})
      @circuit_breaker_options.merge!(
        exceptions: opts.fetch(:exceptions, DEFAULT_EXCEPTIONS)
      )
    end

    def default_value
      return @default_value if @default_value

      default = opts.fetch(:default_value) do
        lambda { |service_response, exception| NullResponse.new(service_response, exception) }
      end

      @default_value = if default.respond_to?(:call)
                         default
                       else
                         lambda { |*| default }
                       end
    end

    def open_circuit?(response)
      opts[:open_circuit].call(response)
    end

    def circuitbox
      @circuitbox ||= opts.fetch(:circuitbox, Circuitbox)
    end

    def circuit_open_value(env, service_response, exception)
      env[:circuit_breaker_default_value] || default_value.call(service_response, exception)
    end

    def circuit(env)
      id = identifier.respond_to?(:call) ? identifier.call(env) : identifier
      circuitbox.circuit id, circuit_breaker_options
    end
  end
end
