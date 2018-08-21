# frozen_string_literal: true

require 'test_helper'
require 'circuitbox/faraday_middleware'

class SentialException < StandardError; end

class Circuitbox
  class FaradayMiddlewareTest < Minitest::Test
    attr_reader :app

    def setup
      @app = gimme
      Circuitbox.configure { |config| config.default_circuit_store = Moneta.new(:Memory, expires: true) }
    end

    def test_default_identifier
      env = { url: URI('http://yammer.com/') }
      assert_equal 'yammer.com', FaradayMiddleware.new(app).identifier.call(env)
    end

    def test_overwrite_identifier
      middleware = FaradayMiddleware.new(app, identifier: 'sential')
      assert_equal middleware.identifier, 'sential'
    end

    def test_overwrite_default_value_generator_lambda
      stub_circuitbox
      env = { url: URI('http://yammer.com/') }
      give(circuitbox).circuit('yammer.com', anything) { circuit }
      give(circuit).run! { raise Circuitbox::Error }
      default_value_generator = lambda { |response| :sential }
      middleware = FaradayMiddleware.new(app,
                                         circuitbox: circuitbox,
                                         default_value: default_value_generator)
      assert_equal :sential, middleware.call(env)
    end

    def test_default_value_generator_lambda_passed_error
      stub_circuitbox
      env = { url: URI('http://yammer.com/') }
      give(circuitbox).circuit('yammer.com', anything) { circuit }
      give(circuit).run! { raise Circuitbox::Error, 'error text' }
      default_value_generator = ->(_, error) { error.message }
      middleware = FaradayMiddleware.new(app,
                                         circuitbox: circuitbox,
                                         default_value: default_value_generator)
      assert_equal 'error text', middleware.call(env)
    end

    def test_overwrite_default_value_generator_static_value
      stub_circuitbox
      env = { url: URI('http://yammer.com/') }
      give(circuitbox).circuit('yammer.com', anything) { circuit }
      give(circuit).run! { raise Circuitbox::Error }
      middleware = FaradayMiddleware.new(app, circuitbox: circuitbox, default_value: :sential)
      assert_equal :sential, middleware.call(env)
    end

    def test_default_exceptions
      middleware = FaradayMiddleware.new(app)
      assert_includes middleware.exceptions, Faraday::Error::TimeoutError
      assert_includes middleware.exceptions, FaradayMiddleware::RequestFailed
    end

    def test_overridde_success_response
      env = { url: URI('http://yammer.com/') }
      app = gimme
      give(app).call(anything) { Faraday::Response.new(status: 500) }
      error_response = ->(_) { false }
      response = FaradayMiddleware.new(app, open_circuit: error_response).call(env)
      assert_kind_of Faraday::Response, response
      assert_equal response.status, 500
      assert response.finished?
      refute response.success?
    end

    def test_default_success_response
      env = { url: URI('http://yammer.com/') }
      app = gimme
      give(app).call(anything) { Faraday::Response.new(status: 500) }
      response = FaradayMiddleware.new(app).call(env)
      assert_kind_of Faraday::Response, response
      assert_equal response.status, 503
      assert response.finished?
      refute response.success?
    end

    def test_default_open_circuit_does_not_trip_on_400
      env = { url: URI('http://yammer.com/') }
      app = gimme
      give(app).call(anything) { Faraday::Response.new(status: 400) }
      response = FaradayMiddleware.new(app).call(env)
      assert_kind_of Faraday::Response, response
      assert_equal response.status, 400
      assert response.finished?
      refute response.success?
    end

    def test_default_open_circuit_does_trip_on_nil
      env = { url: URI('http://yammer.com/') }
      app = gimme
      give(app).call(anything) { Faraday::Response.new(status: nil) }
      response = FaradayMiddleware.new(app).call(env)
      assert_kind_of Faraday::Response, response
      assert_equal response.status, 503
      assert response.finished?
      refute response.success?
    end

    def test_overwrite_exceptions
      middleware = FaradayMiddleware.new(app, exceptions: [SentialException])
      assert_includes middleware.exceptions, SentialException
    end

    def test_pass_circuit_breaker_options
      stub_circuitbox
      env = { url: URI('http://yammer.com/') }
      expected_circuit_breaker_options = {
        sential: :sential,
        exceptions: FaradayMiddleware::DEFAULT_EXCEPTIONS
      }
      give(circuitbox).circuit('yammer.com', expected_circuit_breaker_options) { circuit }
      options = { circuitbox: circuitbox, circuit_breaker_options: { sential: :sential } }
      middleware = FaradayMiddleware.new(app, options)
      middleware.call(env)

      verify(circuitbox, 1.times).circuit('yammer.com', expected_circuit_breaker_options)
    end

    def test_overwrite_circuitbreaker_default_value
      stub_circuitbox
      env = { url: URI('http://yammer.com/'), circuit_breaker_default_value: :sential }
      give(circuitbox).circuit('yammer.com', anything) { circuit }
      give(circuit).run! { raise Circuitbox::Error }
      middleware = FaradayMiddleware.new(app, circuitbox: circuitbox)
      assert_equal middleware.call(env), :sential
    end

    def test_return_value_closed_circuit
      stub_circuitbox
      env = { url: URI('http://yammer.com/') }
      give(circuit).run! { :sential }
      give(circuitbox).circuit('yammer.com', anything) { circuit }
      middleware = FaradayMiddleware.new(app, circuitbox: circuitbox)
      assert_equal middleware.call(env), :sential
    end

    def test_return_null_response_for_open_circuit
      stub_circuitbox
      env = { url: URI('http://yammer.com/') }
      give(circuit).run! { raise Circuitbox::Error }
      give(circuitbox).circuit('yammer.com', anything) { circuit }
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
