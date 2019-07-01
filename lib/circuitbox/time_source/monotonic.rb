class Circuitbox
  module TimeSource
    module Monotonic
      module_function

      def elapsed_seconds
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end
    end
  end
end
