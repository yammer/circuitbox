class Circuitbox
  class Timer
    class Simple
      def time(service, notifier, metric_name, time_source)
        before = time_source.elapsed_seconds
        result = yield
        total_time = time_source.elapsed_seconds - before
        notifier.metric_gauge(service, metric_name, total_time)
        result
      end
    end
  end
end
