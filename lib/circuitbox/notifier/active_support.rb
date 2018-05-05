# frozen_string_literal: true

class Circuitbox
  class Notifier
    class ActiveSupport
      def notify(circuit_name, event)
        ::ActiveSupport::Notifications.instrument("circuit_#{event}", circuit: circuit_name)
      end

      def notify_warning(circuit_name, message)
        ::ActiveSupport::Notifications.instrument('circuit_warning', circuit: circuit_name, message: message)
      end

      def metric_gauge(circuit_name, gauge, value)
        ::ActiveSupport::Notifications.instrument('circuit_gauge', circuit: circuit_name, gauge: gauge.to_s, value: value)
      end
    end
  end
end
