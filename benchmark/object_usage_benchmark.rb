# frozen_string_literal: true

require 'circuitbox'
require 'moneta'

##
# This looks at the retained object counts over time of different in-memory stores
##

# configuration
iterations_to_run_each_circuit = 5000
frequency_to_report_object_allocations = 150
circuits_to_test = []

logger = Logger.new($stdout)
logger.level = Logger::WARN # so we don't output any debug info

circuits_to_test << Circuitbox::CircuitBreaker.new('circuitbox_memory_store',
                                                   sleep_window: 2,
                                                   time_window: 1,
                                                   logger: logger,
                                                   exceptions: [StandardError],
                                                   cache: Circuitbox::MemoryStore.new)

circuits_to_test << Circuitbox::CircuitBreaker.new('moneta_memory_store',
                                                   sleep_window: 2,
                                                   time_window: 1,
                                                   logger: logger,
                                                   exceptions: [StandardError],
                                                   cache: Moneta.new(:Memory, expires: true, threadsafe: true))

class ObjectUsageBenchmark
  class << self
    def run(circuits, iterations, report_every)
      circuits.each do |circuit|
        puts "Starting object use benchmark for #{circuit.service}"
        puts "Initial object allocations: #{current_object_allocations}"

        total_iterations = 0

        while total_iterations < iterations
          total_iterations += 1

          circuit.run(exception: false) do
            raise StandardError if total_iterations % 4
          end

          # by sleeping we end up causing the circuit to go through
          # multiple time_window's when the iteration count is high
          # and the time window is low.
          sleep 0.1

          next unless (total_iterations % report_every).zero?

          puts "Object report ##{total_iterations / report_every}: #{current_object_allocations}"
        end

        puts "Final object allocations for #{circuit.service}: #{current_object_allocations}"
      end
    end

    private

    def current_object_allocations
      GC.start
      objects = ObjectSpace.count_objects
      "Strings: #{objects[:T_STRING]}, Arrays: #{objects[:T_ARRAY]}, Objects: #{objects[:T_OBJECT]}, Hashes: #{objects[:T_HASH]}"
    end
  end
end

ObjectUsageBenchmark.run(circuits_to_test, iterations_to_run_each_circuit, frequency_to_report_object_allocations)
