# frozen_string_literal: true

require 'test_helper'
require 'circuitbox/excon_middleware'

class SentialException < StandardError; end

class Circuitbox
  class ExconMiddlewareTest < Minitest::Test
    attr_reader :app, :circuitbox, :circuit

    def setup
      @app = gimme
      Circuitbox.configure do |config|
        config.default_circuit_store = Moneta.new(:Memory, expires: true)
        config.default_logger = Logger.new(File::NULL)
      end
    end

    def test_default_identifier
      env = { host: 'yammer.com' }
      assert_equal 'yammer.com', ExconMiddleware.new(app).identifier.call(env)
    end

    def test_overwrite_identifier
      middleware = ExconMiddleware.new(app, identifier: 'sential')
      assert_equal 'sential', middleware.identifier
    end

    def test_overwrite_default_value_generator_lambda
      stub_circuitbox
      env = { host: 'yammer.com' }
      give(circuitbox).circuit('yammer.com', anything) { circuit }
      give(circuit).run { raise Circuitbox::Error }
      default_value_generator = ->(_, _) { :sential }
      middleware = ExconMiddleware.new(app,
                                       circuitbox: circuitbox,
                                       default_value: default_value_generator)
      assert_equal :sential, middleware.error_call(env)
    end

    def test_overwrite_default_value_generator_static_value
      stub_circuitbox
      env = { host: 'yammer.com' }
      give(circuitbox).circuit('yammer.com', anything) { circuit }
      give(circuit).run { raise Circuitbox::Error }
      middleware = ExconMiddleware.new(app, circuitbox: circuitbox, default_value: :sential)
      assert_equal :sential, middleware.error_call(env)
    end

    def test_default_exceptions
      middleware = ExconMiddleware.new(app)
      assert_includes middleware.exceptions, Excon::Errors::Timeout
      assert_includes middleware.exceptions, ExconMiddleware::RequestFailed
    end

    def test_overridde_success_response
      env = { host: 'yammer.com', response: { status: 400 } }
      error_response = ->(response) { response[:status] >= 500 }
      give(app).response_call(anything) { Excon::Response.new(status: 400) }
      mw = ExconMiddleware.new(app, open_circuit: error_response)
      response = mw.response_call(env)
      assert_kind_of Excon::Response, response
      assert_equal 400, response.status
    end

    def test_default_success_response
      env = { host: 'yammer.com', response: { status: 400 } }
      app = gimme
      give(app).response_call(anything) { Excon::Response.new(status: 400) }

      mw = ExconMiddleware.new(app)
      response = mw.response_call(env)

      assert_kind_of Excon::Response, response
      assert_equal 503, response.status
    end

    def test_overwrite_exceptions
      middleware = ExconMiddleware.new(app, exceptions: [SentialException])
      assert_includes middleware.exceptions, SentialException
    end

    def test_pass_circuit_breaker_options
      stub_circuitbox
      env = { host: 'yammer.com' }
      expected_circuit_breaker_options = {
        sential: :sential,
        exceptions: ExconMiddleware::DEFAULT_EXCEPTIONS
      }
      give(circuitbox).circuit('yammer.com', expected_circuit_breaker_options) { circuit }
      options = { circuitbox: circuitbox, circuit_breaker_options: { sential: :sential } }
      middleware = ExconMiddleware.new(app, options)
      middleware.request_call(env)

      verify(circuitbox).circuit('yammer.com', expected_circuit_breaker_options)
    end

    def test_overwrite_circuitbreaker_default_value
      stub_circuitbox
      env = { host: 'yammer.com', circuit_breaker_default_value: :sential }
      give(circuitbox).circuit('yammer.com', anything) { circuit }
      give(circuit).run { raise Circuitbox::Error }
      middleware = ExconMiddleware.new(app, circuitbox: circuitbox)
      assert_equal :sential, middleware.error_call(env)
    end

    def test_return_null_response_for_open_circuit
      stub_circuitbox
      env = { host: 'yammer.com' }
      give(circuit).run { raise Circuitbox::Error }
      give(circuitbox).circuit('yammer.com', anything) { circuit }
      mw = ExconMiddleware.new(app, circuitbox: circuitbox)
      response = mw.error_call(env)
      assert_kind_of Excon::Response, response
      assert_equal 503, response.status
    end

    def stub_circuitbox
      @circuitbox = gimme
      @circuit = gimme
    end
  end
end
