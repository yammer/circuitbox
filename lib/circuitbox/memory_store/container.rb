require_relative 'monotonic_time'

class Circuitbox
  class MemoryStore
    class Container
      include MonotonicTime

      attr_accessor :value

      def initialize(value:, expiry: 0)
        @value = value
        expires_after(expiry)
      end

      def expired?
        @expires_after > 0 && @expires_after < current_second
      end

      def expires_after(seconds = 0)
        @expires_after = seconds.zero? ? seconds : current_second + seconds
      end
    end
  end
end
