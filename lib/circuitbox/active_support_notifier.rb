require 'circuitbox/notifier'
require 'active_support/notifications'

class Circuitbox
  class ActiveSupportNotifier < Notifier
    def notify(event)
      ActiveSupport::Notifications.instrument("circuit_#{event}", {
        circuit: circuit_name
      })
    end

    def notify_warning(message)
      ActiveSupport::Notifications.instrument('circuit_warning', {
        circuit: circuit_name,
        message: message
      })
    end

    def metric_gauge(gauge, value)
      ActiveSupport::Notifications.instrument('circuit_gauge', {
        circuit: circuit_name,
        gauge: gauge.to_s,
        value: value
      })
    end
  end
end
