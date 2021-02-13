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

      def notify_run(circuit_name, &block)
        ::ActiveSupport::Notifications.instrument('circuit_run', circuit: circuit_name, &block)
      end
    end
  end
end
