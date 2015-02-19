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
      assert @connection.get(@failure_url).status, 503
    end

    def test_closed_circuit_response
      assert @connection.get(@success_url).success?
    end
  end
end
