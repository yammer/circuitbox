require_relative '../integration_helper'

class Circuitbox

  class FaradayMiddlewareTest < Minitest::Test
    include IntegrationHelpers

    attr_reader :connection, :success_url, :failure_url

    @@only_once = false
    def setup
      Circuitbox.configure do |config|
        config.default_circuit_store = Circuitbox::MemoryStore.new
      end

      @connection = Faraday.new do |c|
        c.use FaradayMiddleware
        c.adapter :net_http
      end
      @success_url = "http://localhost:4711"
      @failure_url = "http://localhost:4712"

      if !@@only_once
        FakeServer.create(4711, ['200', {'Content-Type' => 'text/plain'}, ["Success!"]])
        FakeServer.create(4712, ['500', {'Content-Type' => 'text/plain'}, ["Failure!"]])
        @@only_once = true
      end
    end

    def test_circuit_does_not_open_for_below_threshhold_failed_requests
      4.times { connection.get(failure_url) }
      assert_equal connection.get(success_url).status, 200
    end

    def test_failure_circuit_response
      failure_response = connection.get(failure_url)
      assert_equal failure_response.status, 503
      assert_match failure_response.original_response.body, "Failure!"
    end

    def test_open_circuit_response
      open_circuit
      open_circuit_response = connection.get(failure_url)
      assert_equal open_circuit_response.status, 503
      assert_nil open_circuit_response.original_response
      assert_kind_of Circuitbox::OpenCircuitError, open_circuit_response.original_exception
    end

    def test_closed_circuit_response
      result = connection.get(success_url)
      assert result.success?
    end
  end
end
