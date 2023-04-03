# frozen_string_literal: true

class Circuitbox
  module Notifier
    class ActiveSupport
      def notify(circuit_name, event)
        ::ActiveSupport::Notifications.instrument("#{event}.circuitbox", circuit: circuit_name)
      end

      def notify_warning(circuit_name, message)
        ::ActiveSupport::Notifications.instrument('warning.circuitbox', circuit: circuit_name, message: message)
      end

      def notify_run(circuit_name, &block)
        ::ActiveSupport::Notifications.instrument('run.circuitbox', circuit: circuit_name, &block)
      end
    end
  end
end
