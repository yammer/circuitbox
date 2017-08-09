class Circuitbox
  class Timer
    class Null
      def time(_service, _notifier, _metric_name)
        yield
      end
    end
  end
end
