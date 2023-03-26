# frozen_string_literal: true

class Circuitbox
  module TimeHelper
    module Monotonic
      module_function

      def current_second
        Process.clock_gettime(Process::CLOCK_MONOTONIC, :second)
      end
    end
  end
end
