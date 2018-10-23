# frozen-string-literal: true

require_relative 'monotonic_time'

class Circuitbox
  class MemoryStore
    class Compactor
      include MonotonicTime

      attr_reader :store, :frequency, :compact_after

      def initialize(store:, frequency:)
        @store = store
        @frequency = frequency
        set_next_compaction_time
      end

      def run
        compaction_attempted_at = current_second

        return unless compact_after < compaction_attempted_at

        @store.delete_if { |_, value| value.expired_at?(compaction_attempted_at) }

        set_next_compaction_time
      end

    private

      def set_next_compaction_time
        @compact_after = current_second + frequency
      end
    end
  end
end
