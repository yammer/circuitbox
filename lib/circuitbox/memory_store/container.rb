require 'circuitbox/time_source/monotonic'

class Circuitbox
  class MemoryStore
    class Container
      include Circuitbox::TimeSource::Monotonic

      attr_accessor :value

      def initialize(value:, expiry: 0)
        @value = value
        expires_after(expiry)
      end

      def expired?
        @expires_after > 0 && @expires_after < elapsed_seconds
      end

      def expired_at?(clock_second)
        @expires_after > 0 && @expires_after < clock_second
      end

      def expires_after(seconds = 0)
        @expires_after = seconds.zero? ? seconds : elapsed_seconds + seconds
      end
    end
  end
end
