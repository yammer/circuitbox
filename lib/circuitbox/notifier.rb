class Circuitbox
  class Notifier
    def initialize(service, partition=nil)
      @service   = service
      @partition = partition
    end

    def notify(event)
      return unless notification_available?
      ActiveSupport::Notifications.instrument("circuit_#{event}", circuit: circuit_name)
    end

    def notify_warning(message)
      return unless notification_available?
      ActiveSupport::Notifications.instrument("circuit_warning", { circuit: circuit_name, message: message})
    end

    def metric_gauge(gauge, value)
      return unless notification_available?
      ActiveSupport::Notifications.instrument("circuit_gauge", { circuit: circuit_name, gauge: gauge.to_s, value: value })
    end

    private
    def circuit_name
      circuit_name = @service.to_s
      circuit_name += ":#{@partition}" if @partition
    end

    def notification_available?
      defined? ActiveSupport::Notifications
    end
  end
end
