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
      @failure_url = "http://127.0.0.1:4713"

      if !@@only_once
        pid = fork do
          Rack::Handler::WEBrick.run(lambda { |env| [500, {}, ["Failure"]] },
                                     Port: 4713,
                                     AccessLog: [],
                                     Logger: WEBrick::Log.new(DEV_NULL))
        end
        sleep 0.5
        Minitest.after_run { Process.kill "KILL", pid }
      end
    end

    def teardown
      Circuitbox.configure { |config| config.default_circuit_store = Moneta.new(:Memory, expires: true) }
    end

    def test_circuit_opens_cross_process
      # Open the circuit via a different process
      pid = fork do
        con = Faraday.new do |c|
          c.use FaradayMiddleware, identifier: "circuitbox_test_cross_process",
            circuit_breaker_options: { cache: Moneta.new(:PStore, file: dbfile) }
          c.adapter :typhoeus
        end
        open_circuit(con)
      end
      Process.wait pid
      response = connection.get(failure_url)
      assert response.original_response.nil?, "opening the circuit from a different process should be respected in the main process"
    end
  end
end
