# frozen_string_literal: true

class Circuitbox
  class Timer
    class Monotonic
      class << self
        def supported?
          defined?(Process::CLOCK_MONOTONIC)
        end

        def now
          Process.clock_gettime(Process::CLOCK_MONOTONIC)
        end
      end
    end

    class Default
      class << self
        def supported?
          true
        end

        def now
          Time.now.to_f
        end
      end
    end

    class << self
      def measure(service, notifier, metric_name)
        before = now
        yield
      ensure
        total_time = now - before
        notifier.metric_gauge(service, metric_name, total_time)
      end

      private

      if Monotonic.supported?
        def now
          Monotonic.now
        end
      else
        def now
          Default.now
        end
      end
    end
  end
end
