require "test_helper"
require "faraday"
require "circuitbox/faraday_middleware"
require "rack"

class FakeServer
  def self.instance
    @@instance ||= FakeServer.new
    # if the FakeServer is used kill all of them after the tests are done
    Minitest.after_run { FakeServer.shutdown }
    @@instance
  end

  def initialize
    @servers = []
  end

  def self.create(port, result)
    FakeServer.instance.create(port, result)
  end

  def self.shutdown
    FakeServer.instance.shutdown
  end

  def shutdown
    @servers.map(&:exit)
    @servers = []
  end

  def create(port, result)
    @servers << Thread.new do
      Rack::Handler::WEBrick.run(Proc.new { |env| result },
                                 Port: port,
                                 AccessLog: [],
                                 Logger: WEBrick::Log.new(DEV_NULL))
    end
    sleep 0.5 # wait for the server to spin up
  end
end

module IntegrationHelpers
  def open_circuit(c = connection)
    volume_threshold = Circuitbox::CircuitBreaker::DEFAULTS[:volume_threshold]
    (volume_threshold + 1).times { c.get(failure_url) }
  end
end

