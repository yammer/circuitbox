# frozen_string_literal: true

require_relative '../time_helper/monotonic'

class Circuitbox
  class MemoryStore
    class Container
      include TimeHelper::Monotonic

      attr_accessor :value

      def initialize(value:, expiry: 0)
        @value = value
        expires_after(expiry)
      end

      def expired?
        @expires_after.positive? && @expires_after < current_second
      end

      def expired_at?(clock_second)
        @expires_after.positive? && @expires_after < clock_second
      end

      def expires_after(seconds = 0)
        @expires_after = seconds.zero? ? seconds : current_second + seconds
      end
    end
  end
end
