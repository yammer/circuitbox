class Circuitbox
  class Timer
    class Monotonic
      def initialize(time_unit = :milliseconds)
        @time_unit = time_unit
      end

      def time(service, notifier, metric_name)
        before = Process.clock_gettime(Process::CLOCK_MONOTONIC, @time_unit)
        result = yield
        after = Process.clock_gettime(Process::CLOCK_MONOTONIC, @time_unit)
        notifier.metric_gauge(service, metric_name, before - after)
        result
      end
    end
  end
end
