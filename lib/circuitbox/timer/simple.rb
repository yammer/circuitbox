class Circuitbox
  class Timer
    class Simple
      def time(service, notifier, metric_name)
        before = Time.now.to_f
        result = yield
        after = Time.now.to_f
        notifier.metric_gauge(service, metric_name, after - before)
        result
      end
    end
  end
end
