class Circuitbox
  class Timer
    class Simple
      def time(service, notifier, metric_name)
        before = Time.now.to_f
        result = yield
        total_time = Time.now.to_f - before
        notifier.metric_gauge(service, metric_name, total_time)
        result
      end
    end
  end
end
