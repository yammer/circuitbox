require "integration_helper"
require "tempfile"
require "typhoeus/adapters/faraday"
require "pstore"

class Circuitbox

  class CrossProcessTest < Minitest::Test
    include IntegrationHelpers

    attr_reader :connection, :failure_url, :dbfile

    @@only_once = false
    def setup
      if !@@only_once
        @dbfile = Tempfile.open("circuitbox_test_cross_process")
      end

      @connection = Faraday.new do |c|
        c.use FaradayMiddleware, identifier: "circuitbox_test_cross_process",
          circuit_breaker_options: { cache: Moneta.new(:PStore, file: dbfile) }
        c.adapter :typhoeus # support in_parallel
      end
      @failure_url = "http://localhost:4713"

      if !@@only_once
        thread = Thread.new do
          Rack::Handler::WEBrick.run(Proc.new { |env| ["Failure"] },
                                     Port: 4713,
                                     AccessLog: [],
                                     Logger: WEBrick::Log.new(DEV_NULL))
        end
        Minitest.after_run { thread.exit }
      end
    end

    def teardown
      Circuitbox.reset
    end

    def test_circuit_opens_cross_process
      # Open the circuit via a different process
      pid = fork do
        con = Faraday.new do |c|
          c.use FaradayMiddleware, identifier: "circuitbox_test_cross_process",
            circuit_breaker_options: { cache: Moneta.new(:PStore, file: dbfile) }
        end
        open_circuit(con)
      end
      Process.wait pid
      response = connection.get(failure_url)
      assert response.original_response.nil?, "opening the circuit from a different process should be respected in the main process"
    end
  end
end
