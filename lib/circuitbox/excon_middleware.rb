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
      def initialize(response, exception)
        @original_response = response
        @original_exception = exception
        super(status: 503, response_headers: {})
      end

      def []=(key, value)
        @data[key] = value
      end
    end

    attr_reader :opts

    def initialize(stack, opts = {})
      @stack = stack
      default_options = { open_circuit: lambda { |response| response[:status] >= 400 } }
      @opts = default_options.merge(opts)
      super(stack)
    end

    def error_call(datum)
      circuit(datum).run!(run_options(datum)) do
        raise RequestFailed
      end
    rescue Circuitbox::Error => exception
      circuit_open_value(datum, datum[:response], exception)
    end

    def request_call(datum)
      circuit(datum).run!(run_options(datum)) do
        @stack.request_call(datum)
      end
    end

    def response_call(datum)
      circuit(datum).run!(run_options(datum)) do
        raise RequestFailed if open_circuit?(datum[:response])
      end
      @stack.response_call(datum)
    rescue Circuitbox::Error => exception
      circuit_open_value(datum, datum[:response], exception)
    end

    def identifier
      @identifier ||= opts.fetch(:identifier, ->(env) { env[:path] })
    end

    def exceptions
      circuit_breaker_options[:exceptions]
    end

    private

    def circuit(datum)
      id = identifier.respond_to?(:call) ? identifier.call(datum) : identifier
      circuitbox.circuit id, circuit_breaker_options
    end

    def run_options(datum)
      opts.merge(datum)[:circuit_breaker_run_options] || {}
    end

    def open_circuit?(response)
      opts[:open_circuit].call(response)
    end

    def circuitbox
      @circuitbox ||= opts.fetch(:circuitbox, Circuitbox)
    end

    def circuit_open_value(env, response, exception)
      env[:circuit_breaker_default_value] || default_value.call(response, exception)
    end

    def circuit_breaker_options
      return @circuit_breaker_options if @circuit_breaker_options

      @circuit_breaker_options = opts.fetch(:circuit_breaker_options, {})
      @circuit_breaker_options.merge!(
        exceptions: opts.fetch(:exceptions, DEFAULT_EXCEPTIONS)
      )
    end

    def default_value
      return @default_value if @default_value

      default = opts.fetch(:default_value) do
        lambda { |response, exception| NullResponse.new(response, exception) }
      end

      @default_value = if default.respond_to?(:call)
                         default
                       else
                         lambda { |*| default }
                       end
    end
  end
end
