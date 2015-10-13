require 'test_helper'
require 'circuitbox/excon_middleware'

class SentialException < StandardError; end

class Circuitbox
  class ExconMiddlewareTest < Minitest::Test

    attr_reader :app

    def setup
      @app = gimme
    end

    def test_default_identifier
      env = { url: "sential" }
      assert_equal "sential", ExconMiddleware.new(app).identifier.call(env)
    end

    def test_overwrite_identifier
      middleware = ExconMiddleware.new(app, identifier: "sential")
      assert_equal middleware.identifier, "sential"
    end

    def test_overwrite_default_value_generator_lambda
      stub_circuitbox
      env = { url: "url" }
      give(circuitbox).circuit("url", anything) { circuit }
      give(circuit).run!(anything) { raise Circuitbox::Error }
      default_value_generator = lambda { :sential }
      middleware = ExconMiddleware.new(app,
                                         circuitbox: circuitbox,
                                         default_value: default_value_generator)
      assert_equal :sential, middleware.error_call(env)
    end

    def test_overwrite_default_value_generator_static_value
      stub_circuitbox
      env = { url: "url" }
      give(circuitbox).circuit("url", anything) { circuit }
      give(circuit).run!(anything) { raise Circuitbox::Error }
      middleware = ExconMiddleware.new(app, circuitbox: circuitbox, default_value: :sential)
      assert_equal :sential, middleware.error_call(env)
    end

    def test_default_exceptions
      middleware = ExconMiddleware.new(app)
      assert_includes middleware.exceptions, Excon::Errors::Timeout
      assert_includes middleware.exceptions, ExconMiddleware::RequestFailed
    end

    def test_overridde_success_response
      env = { url: "url", status: 400 }
      error_response = lambda { |r| r.status >= 500 }
      mw = ExconMiddleware.new(app, open_circuit: error_response)
      response = mw.response_call(env)
      assert_kind_of Excon::Response, response
      assert_equal response.status, 400
    end

    def test_default_success_response
      env = { url: "url", status: 400 }
      app = gimme
      give(app).request_call(anything) { Excon::Response.new(status: 400) }
      response = nil

      begin
        mw = ExconMiddleware.new(app)
        mw.response_call(env)
      rescue
        response = mw.error_call(env)
      end

      assert_kind_of Excon::Response, response
      assert_equal response.status, 503
    end

    def test_overwrite_exceptions
      middleware = ExconMiddleware.new(app, exceptions: [SentialException])
      assert_includes middleware.exceptions, SentialException
    end

    def test_pass_circuit_breaker_run_options
      stub_circuitbox
      give(circuit).run!(:sential)
      give(circuitbox).circuit("url", anything) { circuit }
      env = { url: "url", circuit_breaker_run_options: :sential }
      middleware = ExconMiddleware.new(app, circuitbox: circuitbox)
      middleware.request_call(env)
      verify(circuit, 1.times).run!(:sential)
    end

    def test_pass_circuit_breaker_options
      stub_circuitbox
      env = { url: "url" }
      expected_circuit_breaker_options = {
        sential: :sential,
        exceptions: ExconMiddleware::DEFAULT_EXCEPTIONS
      }
      give(circuitbox).circuit("url", expected_circuit_breaker_options) { circuit }
      options = { circuitbox: circuitbox, circuit_breaker_options: { sential: :sential } }
      middleware = ExconMiddleware.new(app, options)
      middleware.request_call(env)

      verify(circuitbox, 1.times).circuit("url", expected_circuit_breaker_options)
    end

    def test_overwrite_circuitbreaker_default_value
      stub_circuitbox
      env = { url: "url", circuit_breaker_default_value: :sential }
      give(circuitbox).circuit("url", anything) { circuit }
      give(circuit).run!(anything) { raise Circuitbox::Error }
      middleware = ExconMiddleware.new(app, circuitbox: circuitbox)
      assert_equal middleware.error_call(env), :sential
    end

    def test_return_null_response_for_open_circuit
      stub_circuitbox
      env = { url: "url" }
      give(circuit).run!(anything) { raise Circuitbox::Error }
      give(circuitbox).circuit("url", anything) { circuit }
      mw = ExconMiddleware.new(app, circuitbox: circuitbox)
      response = mw.error_call(env)
      assert_kind_of Excon::Response, response
      assert_equal response.status, 503
    end

    attr_reader :circuitbox, :circuit
    def stub_circuitbox
      @circuitbox = gimme
      @circuit = gimme
    end
  end
end
