class Circuitbox
  class Timer
    class Monotonic
      def initialize(time_unit = :milliseconds)
        @time_unit = time_unit
      end

      def time(service, notifier, metric_name)
        before = Process.clock_gettime(Process::CLOCK_MONOTONIC, @time_unit)
        result = yield
        total_time = Process.clock_gettime(Process::CLOCK_MONOTONIC, @time_unit) - before
        notifier.metric_gauge(service, metric_name, total_time)
        result
      end
    end
  end
end
