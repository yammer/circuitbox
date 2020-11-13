# frozen_string_literal: true

class Circuitbox
  class MemoryStore
    module MonotonicTime
      module_function

      def current_second
        Process.clock_gettime(Process::CLOCK_MONOTONIC, :second)
      end
    end
  end
end
