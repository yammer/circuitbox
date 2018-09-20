# frozen_string_literal: true

class Circuitbox
  class CircuitBreaker
    module LoggerMessages
      def circuit_open_message
        @circuit_open_message ||= "[CIRCUIT] open: skipping #{service}"
      end

      def circuit_closed_querying_message
        @circuit_closed_querying_message ||= "[CIRCUIT] closed: querying #{service}"
      end

      def circuit_closed_query_success_message
        @circuit_closed_query_success_message ||= "[CIRCUIT] closed: #{service} query success"
      end

      def circuit_closed_failure_message
        @closed_failure_message ||= "[CIRCUIT] closed: detected #{service} failure"
      end

      def circuit_opening_message
        @opening_message ||= "[CIRCUIT] opening #{service} circuit"
      end
    end
  end
end
