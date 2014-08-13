require 'test_helper'
require_relative '../lib/circuitbox/faraday_middleware'

class Circuitbox
  class FaradayMiddlewareTest < Minitest::Test

    def setup
      @app = gimme
      @env = gimme
      give(@env).url { 'URL' }

      @middleware = FaradayMiddleware.new @app,
                                          :identifier => 'ID',
                                          :exceptions => [StandardError]
    end

    def test_should_use_env_url_proc_if_not_provided_as_identifier
      middleware = FaradayMiddleware.new @app, :exceptions => gimme
      assert middleware.identifier.is_a?(Proc)
      assert_equal 'URL', middleware.identifier.call(@env)
    end

    def test_should_use_request_error_if_not_provided_as_exception
      middleware = FaradayMiddleware.new @app, :identifier => 'ID'
      assert_equal [Faraday::Error::TimeoutError],
                   middleware.exceptions
    end

    def test_successful_call
      @middleware.call(@env)
    end

    def test_failed_call
      assert_raises Circuitbox::RequestError do
        give(@env).success? { false }
        @middleware.on_complete(@env)
      end
    end

  end
end
