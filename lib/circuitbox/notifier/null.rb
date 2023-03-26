# frozen_string_literal: true

class Circuitbox
  module Notifier
    class Null
      def notify(_circuit_name, _event); end

      def notify_warning(_circuit_name, _message); end

      def notify_run(_circuit_name)
        yield
      end
    end
  end
end
