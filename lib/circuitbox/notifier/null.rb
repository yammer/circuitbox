# frozen_string_literal: true

class Circuitbox
  class Notifier
    class Null
      def notify(_, _); end

      def notify_warning(_, _); end

      def metric_gauge(_, _, _); end
    end
  end
end
