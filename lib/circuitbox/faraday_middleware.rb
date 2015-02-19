require 'faraday'
require 'circuitbox'

class Circuitbox
  class FaradayMiddleware < Faraday::Middleware
    class RequestFailed < StandardError ; end

    DEFAULT_EXCEPTIONS = [
      Faraday::Error::TimeoutError,
      RequestFailed,
    ]

    class NullResponse < Faraday::Response
      def initialize
        super(status: 503, response_headers: {})
      end
    end

    attr_reader :opts

    def initialize(app, opts = {})
      @app = app
      @opts = opts
      super(app)
    end

    def call(request_env)
      response = circuit(request_env).run(run_options(request_env)) do
        @app.call(request_env).on_complete do |response_env|
          raise RequestFailed unless response_env.success?
        end
      end

      response.nil? ? circuit_open_value(request_env) : response
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
        exceptions: opts.fetch(:exceptions, DEFAULT_EXCEPTIONS),
        volume_threshold: 10
      )
    end

    def default_value
      @default_value ||= opts.fetch(:default_value, NullResponse.new)
    end

    def circuitbox
      @circuitbox ||= opts.fetch(:circuitbox, Circuitbox)
    end

    def circuit_open_value(env)
      env[:circuit_breaker_default_value] || default_value
    end

    def circuit(env)
      id = identifier.respond_to?(:call) ? identifier.call(env) : identifier
      circuitbox.circuit id, circuit_breaker_options
    end
  end
end
