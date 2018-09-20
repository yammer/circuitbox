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
        return unless compact_after < current_second

        @store.delete_if { |_, value| value.expired? }

        set_next_compaction_time
      end

    private

      def set_next_compaction_time
        @compact_after = current_second + frequency
      end
    end
  end
end
