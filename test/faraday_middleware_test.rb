# frozen_string_literal: true

require 'test_helper'
require 'moneta'
require 'circuitbox/faraday_middleware'
require 'rubygems'

class SentialException < StandardError; end

class Circuitbox
  class FaradayMiddlewareTest < Minitest::Test
    attr_reader :app

    def setup
      @app = gimme
      Circuitbox.configure do |config|
        config.default_circuit_store = Moneta.new(:Memory, expires: true)
      end
    end

    def test_default_identifier
      middleware = FaradayMiddleware.new(app)
      middleware_opts = opts_from(middleware)
      env = { url: URI('http://yammer.com/') }

      assert_equal 'yammer.com', middleware_opts[:identifier].call(env)
    end

    def test_default_identifier_no_host
      middleware = FaradayMiddleware.new(app)
      middleware_opts = opts_from(middleware)
      uri = gimme
      give(uri).host { nil }
      give(uri).to_s { 'yam' }
      env = { url: uri }

      assert_equal 'yam', middleware_opts[:identifier].call(env)
    end

    def test_overwrite_identifier
      middleware = FaradayMiddleware.new(app, identifier: 'sential')
      middleware_opts = opts_from(middleware)

      assert_equal 'sential', middleware_opts[:identifier]
    end

    def test_overwrite_default_value_generator_lambda
      circuit = gimme
      env = { url: URI('http://yammer.com/') }

      give(circuit).run { raise Circuitbox::Error }
      Circuitbox.expects(:circuit).with('yammer.com', anything).returns(circuit)

      default_value_generator = ->(_, _) { :sential }
      middleware = FaradayMiddleware.new(app, default_value: default_value_generator)
      assert_equal :sential, middleware.call(env)
    end

    def test_default_value_generator_lambda_passed_error
      circuit = gimme
      env = { url: URI('http://yammer.com/') }

      give(circuit).run { raise Circuitbox::Error.new('error text') }
      Circuitbox.expects(:circuit).with('yammer.com', anything).returns(circuit)

      default_value_generator = ->(_, error) { error.message }
      middleware = FaradayMiddleware.new(app, default_value: default_value_generator)
      assert_equal 'error text', middleware.call(env)
    end

    def test_overwrite_default_value_generator_static_value
      circuit = gimme
      env = { url: URI('http://yammer.com/') }

      give(circuit).run { raise Circuitbox::Error }
      Circuitbox.expects(:circuit).with('yammer.com', anything).returns(circuit)

      middleware = FaradayMiddleware.new(app, default_value: :sential)
      assert_equal :sential, middleware.call(env)
    end

    def test_default_exceptions
      middleware = FaradayMiddleware.new(app)
      middleware_opts = opts_from(middleware)
      circuit_breaker_options = middleware_opts[:circuit_breaker_options]

      assert_includes circuit_breaker_options[:exceptions], Faraday::TimeoutError
      assert_includes circuit_breaker_options[:exceptions], FaradayMiddleware::RequestFailed
    end

    def test_overridde_success_response
      env = { url: URI('http://yammer.com/') }
      app = gimme
      give(app).call(anything) { Faraday::Response.new(status: 500) }
      error_response = ->(_) { false }
      response = FaradayMiddleware.new(app, open_circuit: error_response).call(env)
      assert_kind_of Faraday::Response, response
      assert_equal 500, response.status
      assert response.finished?
      refute response.success?
    end

    def test_default_success_response
      env = { url: URI('http://yammer.com/') }
      app = gimme
      give(app).call(anything) { Faraday::Response.new(status: 500) }
      response = FaradayMiddleware.new(app).call(env)
      assert_kind_of Faraday::Response, response
      assert_equal 503, response.status
      assert response.finished?
      refute response.success?
    end

    def test_default_open_circuit_does_not_trip_on_400
      env = { url: URI('http://yammer.com/') }
      app = gimme
      give(app).call(anything) { Faraday::Response.new(status: 400) }
      response = FaradayMiddleware.new(app).call(env)
      assert_kind_of Faraday::Response, response
      assert_equal 400, response.status
      assert response.finished?
      refute response.success?
    end

    def test_default_open_circuit_does_trip_on_nil
      env = { url: URI('http://yammer.com/') }
      app = gimme
      give(app).call(anything) { Faraday::Response.new(status: nil) }
      response = FaradayMiddleware.new(app).call(env)
      assert_kind_of Faraday::Response, response
      assert_equal 503, response.status
      assert response.finished?
      refute response.success?
    end

    def test_overwrite_exceptions
      middleware = FaradayMiddleware.new(app, circuit_breaker_options: { exceptions: [SentialException] })
      middleware_opts = opts_from(middleware)
      circuit_breaker_options = middleware_opts[:circuit_breaker_options]

      assert_includes circuit_breaker_options[:exceptions], SentialException
    end

    def test_pass_circuit_breaker_options
      circuit = gimme
      env = { url: URI('http://yammer.com/') }
      expected_circuit_breaker_options = {
        sential: :sential,
        exceptions: FaradayMiddleware::DEFAULT_EXCEPTIONS
      }
      Circuitbox.expects(:circuit).with('yammer.com', expected_circuit_breaker_options).returns(circuit)

      options = { circuit_breaker_options: { sential: :sential } }
      middleware = FaradayMiddleware.new(app, options)
      middleware.call(env)
    end

    def test_overwrite_circuitbreaker_default_value
      circuit = gimme
      env = { url: URI('http://yammer.com/'), circuit_breaker_default_value: :sential }

      give(circuit).run { raise Circuitbox::Error }
      Circuitbox.expects(:circuit).with('yammer.com', anything).returns(circuit)

      middleware = FaradayMiddleware.new(app)
      assert_equal :sential, middleware.call(env)
    end

    def test_return_value_closed_circuit
      circuit = gimme
      env = { url: URI('http://yammer.com/') }

      give(circuit).run { :sential }
      Circuitbox.expects(:circuit).with('yammer.com', anything).returns(circuit)

      middleware = FaradayMiddleware.new(app)
      assert_equal :sential, middleware.call(env)
    end

    def test_return_null_response_for_open_circuit
      circuit = gimme
      env = { url: URI('http://yammer.com/') }

      give(circuit).run { raise Circuitbox::Error }
      Circuitbox.expects(:circuit).with('yammer.com', anything).returns(circuit)

      response = FaradayMiddleware.new(app).call(env)
      assert_kind_of Faraday::Response, response
      assert_equal 503, response.status
      assert response.finished?
      refute response.success?
    end

    private

    def opts_from(middleware)
      middleware.instance_variable_get(:@opts)
    end
  end
end
