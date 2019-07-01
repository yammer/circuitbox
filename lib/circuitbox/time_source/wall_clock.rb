class Circuitbox
  module TimeSource
    module WallClock
      module_function

      def elapsed_seconds
        Time.now.to_f
      end
    end
  end
end
