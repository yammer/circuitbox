class Circuitbox
  class Notifier
    def initialize(service, partition = nil)
      @service   = service
      @partition = partition
    end

    private

    def circuit_name
      [@service, @partition].compact.map(&:to_s).join(':')
    end
  end

  class NullNotifier < Notifier
    def notify(event); end

    def notify_warning(message); end

    def metric_gauge(gauge, value); end
  end
end
