require "delegate"

class Circuitbox

  class Store

    class UnsupportedBackendError < StandardError
    end

    def self.in_process_store
      Moneta.new(:Memory, expires: true)
    end

    def self.cross_process_store(file, compact_now = DaybreakCrossProcessStore::DEFAULT_COMPACT_DELAY)
      db = Moneta.new(:Daybreak, file: file, expires: true, sync: true)
      DaybreakCrossProcessStore.new(db, compact_now)
    end
  end

  class DaybreakCrossProcessStore < SimpleDelegator

    DEFAULT_COMPACT_DELAY = lambda { |operations| operations > 1000 }

    def initialize(delegate, compact_now = DEFAULT_COMPACT_DELAY)
      super(delegate)

      @handle_compaction = compaction_strategy(delegate, compact_now)
    end

    def increment(*)
      @handle_compaction.call
      backend.load
      super
    end

    def delete(*)
      @handle_compaction.call
      super
    end

    def store(*)
      @handle_compaction.call
      super
    end

    def load(*)
      backend.load
      super
    end

    def [](key)
      backend.load
      super
    end

    def backend
      @_backend ||= find_backend
    end

    private
    def compaction_strategy(delegate, compact_now)
      invocation_count = 0
      @handle_compaction = lambda do
        if compact_now.call(invocation_count)
          backend.compact
          invocation_count = 0
        else
          invocation_count += 1
        end
      end
    end

    # depending on the amount of middleware being used the backend can be buried
    # deep inside moneta, so lets find it by crawling along the adapter chain
    def find_backend
      adapter = __getobj__.adapter
      while adapter.respond_to?(:adapter)
        adapter = adapter.adapter
      end
      adapter.backend
    end
  end
end
