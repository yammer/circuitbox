require 'excon'
require 'circuitbox'

class Circuitbox
  class ExconMiddleware < Excon::Middleware::Base
    class RequestFailed < StandardError; end

    DEFAULT_EXCEPTIONS = [
      Excon::Errors::Timeout,
      RequestFailed
    ]

    class NullResponse < Excon::Response
      def initialize
        super(status: 503, response_headers: {})
      end
    end

    attr_reader :opts

    def initialize(stack, opts = {})
      @stack = stack
      default_options = { open_circuit: lambda { |response| !(200..299).include?(response.status) } }
      @opts = default_options.merge(opts)
      super(stack)
    end

    def error_call(datum)
      circuit_open_value(datum)
    end

    def request_call(datum)
      circuit(datum).run!(run_options(datum)) do
        @stack.request_call(datum)
      end
    end

    def response_call(datum)
      @stack.response_call(datum)
      service_response = Excon::Response.new(datum)
      raise RequestFailed if open_circuit?(service_response)
      service_response
    end

    def identifier
      @identifier ||= opts.fetch(:identifier, ->(env) { env[:url] })
    end

    def exceptions
      circuit_breaker_options[:exceptions]
    end

    private

    def circuit(env)
      id = identifier.respond_to?(:call) ? identifier.call(env) : identifier
      circuitbox.circuit id, circuit_breaker_options
    end

    def run_options(env)
      env[:circuit_breaker_run_options] || {}
    end

    def open_circuit?(response)
      opts[:open_circuit].call(response)
    end

    def circuitbox
      @circuitbox ||= opts.fetch(:circuitbox, Circuitbox)
    end

    def circuit_open_value(env)
      env[:circuit_breaker_default_value] || default_value.call
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
        lambda { NullResponse.new }
      end

      @default_value = if default.respond_to?(:call)
                         default
                       else
                         lambda { |*| default }
                       end
    end
  end
end
