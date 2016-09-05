require "integration_helper"
require "tempfile"

class Circuitbox

  class Failure < StandardError
  end

  class DaybreakCircuitboxTest < Minitest::Test

    def setup
      @dbfile_path = Tempfile.new("store.db").path
      @circuit = Circuitbox.circuit(:daybreak_test,
                                    exceptions: [RuntimeError],
                                    cache: Store.cross_process_store(@dbfile_path))
    end

    def teardown
      @circuit.circuit_store.close
      Circuitbox.reset
    end


    def test_can_use_daybreak_as_storage_backend
      @circuit.run { true }
      @circuit.run { raise "failed" }

      assert_equal 2, @circuit.circuit_store.backend.keys.count, "failure and success keys are stored in daybreak"
    end

    def test_circuit_opens_cross_process
      script = <<-eos
require "circuitbox"

DEV_NULL = (RUBY_PLATFORM =~ /mswin|mingw/ ? "NUL" : "/dev/null")

class Circuitbox
  class CircuitBreaker
    def logger
      @_dev_null_logger ||= Logger.new(DEV_NULL)
    end
  end
end

circuit = Circuitbox.circuit(:daybreak_test,
                             exceptions: [RuntimeError],
                             cache: Circuitbox::Store.cross_process_store("#{@dbfile_path}"))
(Circuitbox::CircuitBreaker::DEFAULTS[:volume_threshold] + 2).times do |i|
  circuit.run { raise "failure" }
end

circuit.circuit_store.close
      eos

      pid = fork do
        exec "ruby", "-e", script
      end

      Process.waitpid pid

      assert_raises(OpenCircuitError) do
        @circuit.run! { raise "failure" }
      end
    end
  end
end


