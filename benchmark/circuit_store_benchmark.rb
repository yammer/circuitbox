require 'circuitbox'
require 'benchmark'
require 'pstore'
require 'tempfile'
require 'tmpdir'
require 'lmdb'
require 'pry'


class Circuitbox
  class CircuitBreaker
    # silence the circuitbreaker logger
    DEV_NULL = (RUBY_PLATFORM =~ /mswin|mingw/ ? "NUL" : "/dev/null")
    def logger
      @_dev_null_logger ||= Logger.new DEV_NULL
    end
  end
end

def service
  # 10% success rate to make the circuitbreaker flip flop
  if rand(10) <= 0
    "success"
  else
    raise RuntimeError, "fail"
  end
end

def run_flip_flopping circuit
  before = circuit.open?
  circuit.run { service }
  after = circuit.open?
  circuit.try_close_next_time if circuit.open?
end

def without_gc
  GC.start
  GC.disable
  yield
  GC.enable
end

def benchmark_circuitbox_method_with_reporter method, reporter
  without_gc { send(method, reporter) }
  Circuitbox.reset
end

def circuit_with_cache cache
  Circuitbox.circuit :performance, CIRCUIT_OPTIONS.merge(cache: cache)
end

CIRCUIT_OPTIONS = {
  exceptions: [RuntimeError],
  sleep_window: 0,
  time_window: 1
}

RUNS = 10000

def circuit_store_memory_one_process reporter
  circuit = circuit_with_cache Moneta.new(:Memory)

  reporter.report "memory:" do
    RUNS.times { run_flip_flopping circuit }
  end

  circuit.circuit_store.close
end

def circuit_store_pstore_one_process reporter
  Tempfile.create("test_circuit_store_pstore_one_process") do |dbfile|
    circuit = circuit_with_cache Moneta.new(:PStore, file: dbfile)

    reporter.report "pstore:" do
      RUNS.times { run_flip_flopping circuit }
    end

    circuit.circuit_store.close
  end
end

def circuit_store_lmdb_one_process reporter
  Dir.mktmpdir("test_circuit_store_lmdb_one_process") do |dbdir|
    circuit = circuit_with_cache Moneta.new(:LMDB, dir: dbdir, db: "circuitbox_lmdb")

    reporter.report "lmdb:" do
      RUNS.times { run_flip_flopping circuit }
    end

    circuit.circuit_store.close
  end
end

def circuit_store_daybreak_one_process reporter
  Tempfile.create("test_circuit_store_daybreak_one_process") do |dbfile|
    circuit = circuit_with_cache Moneta.new(:Daybreak, file: dbfile)

    reporter.report "daybreak:" do
      RUNS.times { run_flip_flopping circuit }
    end

    circuit.circuit_store.close
  end
end

Benchmark.bm(8) do |x|
  benchmark_circuitbox_method_with_reporter :circuit_store_memory_one_process, x
  benchmark_circuitbox_method_with_reporter :circuit_store_lmdb_one_process, x
  benchmark_circuitbox_method_with_reporter :circuit_store_pstore_one_process, x
  benchmark_circuitbox_method_with_reporter :circuit_store_daybreak_one_process, x
end





