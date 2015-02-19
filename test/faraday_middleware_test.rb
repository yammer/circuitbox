require 'test_helper'
require 'circuitbox/faraday_middleware'

class SentialException < StandardError; end

class Circuitbox
  class FaradayMiddlewareTest < Minitest::Test

    attr_reader :app
    def setup
      @app = gimme
      give(@app).run { :run }
    end

    def test_default_identifier
      env = { url: "sential" }
      assert_equal FaradayMiddleware.new(app).identifier.call(env), "sential"
    end

    def test_overwrite_identifier
      middleware = FaradayMiddleware.new(app, identifier: "sential")
      assert_equal middleware.identifier, "sential"
    end

    def test_default_exceptions
      middleware = FaradayMiddleware.new(app)
      assert_includes middleware.exceptions, Faraday::Error::TimeoutError
      assert_includes middleware.exceptions, FaradayMiddleware::RequestFailed
    end

    def test_overwrite_exceptions
      middleware = FaradayMiddleware.new(app, exceptions: [SentialException])
      assert_includes middleware.exceptions, SentialException
    end

    def test_pass_circuit_breaker_run_options
      stub_circuitbox
      give(circuit).run(:sential)
      give(circuitbox).circuit("url", anything) { circuit }
      env = { url: "url", circuit_breaker_run_options: :sential }
      middleware = FaradayMiddleware.new(app, circuitbox: circuitbox)
      middleware.call(env)
      verify(circuit).run(:sential)
    end

    def test_pass_circuit_breaker_options
      stub_circuitbox
      env = { url: "url" }
      expected_circuit_breaker_options = {
        sential: :sential,
        exceptions: FaradayMiddleware::DEFAULT_EXCEPTIONS,
        volume_threshold: 10
      }
      give(circuitbox).circuit("url", expected_circuit_breaker_options) { circuit }
      options = { circuitbox: circuitbox, circuit_breaker_options: { sential: :sential } }
      middleware = FaradayMiddleware.new(app, options)
      middleware.call(env)

      verify(circuitbox).circuit("url", expected_circuit_breaker_options)
    end

    def test_overwrite_circuitbreaker_default_value
      stub_circuitbox
      env = { url: "url", circuit_breaker_default_value: :sential }
      give(circuitbox).circuit("url", anything) { circuit }
      middleware = FaradayMiddleware.new(app, circuitbox: circuitbox)
      assert_equal middleware.call(env), :sential
    end

    def test_return_value_closed_circuit
      stub_circuitbox
      env = { url: "url" }
      give(circuit).run(anything) { :sential }
      give(circuitbox).circuit("url", anything) { circuit }
      middleware = FaradayMiddleware.new(app, circuitbox: circuitbox)
      assert_equal middleware.call(env), :sential
    end

    def test_return_null_response_for_open_circuit
      stub_circuitbox
      env = { url: "url" }
      give(circuit).run(anything) { nil }
      give(circuitbox).circuit("url", anything) { circuit }
      response = FaradayMiddleware.new(app, circuitbox: circuitbox).call(env)
      assert_kind_of Faraday::Response, response
      assert_equal response.status, 503
      assert response.finished?
      refute response.success?
    end

    attr_reader :circuitbox, :circuit
    def stub_circuitbox
      @circuitbox = gimme
      @circuit = gimme
    end
  end
end
