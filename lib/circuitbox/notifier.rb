class Circuitbox
  class Notifier
    def self.notify(event, service, partition = nil)
      return unless defined? ActiveSupport::Notifications

      circuit_name = service
      circuit_name += ":#{partition}" if partition

      ActiveSupport::Notifications.instrument("circuit_#{event}", circuit: circuit_name)
    end
  end
end