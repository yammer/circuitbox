# frozen_string_literal: true

class Circuitbox
  class CircuitBreaker
    module LoggerMessages
      def circuit_skipped_message
        @circuit_skipped_message ||= "[CIRCUIT] #{service}: skipped"
      end

      def circuit_running_message
        @circuit_running_message ||= "[CIRCUIT] #{service}: running"
      end

      def circuit_success_message
        @circuit_success_message ||= "[CIRCUIT] #{service}: success"
      end

      def circuit_failure_message
        @circuit_failure_message ||= "[CIRCUIT] #{service}: failure"
      end

      def circuit_opened_message
        @circuit_opened_message ||= "[CIRCUIT] #{service}: opened"
      end

      def circuit_closed_message
        @circuit_closed_message ||= "[CIRCUIT] #{service}: closed"
      end
    end
  end
end
