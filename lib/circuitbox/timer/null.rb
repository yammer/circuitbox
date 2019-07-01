class Circuitbox
  class Timer
    class Null
      def time(_service, _notifier, _metric_name, _time_source)
        yield
      end
    end
  end
end
