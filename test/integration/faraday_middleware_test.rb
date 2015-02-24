require "integration_helper"

class Circuitbox
  class FaradayMiddlewareTest < Minitest::Test
    @@only_once = false
    def setup
      @connection = Faraday.new do |c|
        c.use FaradayMiddleware
        c.adapter Faraday.default_adapter
      end
      @success_url = "http://localhost:4711"
      @failure_url = "http://localhost:4712"

      if !@@only_once
        FakeServer.create(4711, ['200', {'Content-Type' => 'text/plain'}, ["Success!"]])
        FakeServer.create(4712, ['500', {'Content-Type' => 'text/plain'}, ["Failure!"]])
      end
    end

    def teardown
      Circuitbox.reset
    end

    def test_open_circuit_response
      10.times { @connection.get(@failure_url) } # make the CircuitBreaker open
      open_circuit_response = @connection.get(@failure_url)
      assert open_circuit_response.status, 503
      assert_match open_circuit_response.original_response.body, "Failure!"
    end

    def test_closed_circuit_response
      result = @connection.get(@success_url)
      assert result.success?
    end
  end
end
