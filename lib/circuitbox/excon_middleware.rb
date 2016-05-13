require 'excon'
require 'circuitbox'

class Circuitbox
  class ExconMiddleware < Excon::Middleware::Base
    class RequestFailed < StandardError; end

    DEFAULT_EXCEPTIONS = [
      Excon::Errors::Timeout,
      RequestFailed
    ]

    attr_reader :opts

    def initialize(stack, opts = {})
      @stack = stack
      default_options = { open_circuit: lambda { |response| response[:status] >= 400 } }
      @opts = default_options.merge(opts)
      super(stack)
    end

    def error_call(datum)
      unless datum[:error].is_a? Circuitbox::Error
        circuit(datum).run!(run_options(datum)) do
          raise datum[:error]
        end
      rescue Circuitbox::Error => e
        data[:error] = e
      end
      @stack.error_call(datum)
    end

    def request_call(datum)
      circuit(datum).run!(run_options(datum)) do
        @stack.request_call(datum)
      end
    end

    def response_call(datum)
      # Note: Swallows the Circuitbox::Error, always returns response call
      circuit(datum).run(run_options(datum)) do
        raise RequestFailed if open_circuit?(datum[:response])
      end
      @stack.response_call(datum)
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

    def circuit_breaker_options
      return @circuit_breaker_options if @circuit_breaker_options

      @circuit_breaker_options = opts.fetch(:circuit_breaker_options, {})
      @circuit_breaker_options.merge!(
        exceptions: opts.fetch(:exceptions, DEFAULT_EXCEPTIONS)
      )
    end
  end
end
