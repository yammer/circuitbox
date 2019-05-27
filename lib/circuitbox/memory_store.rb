# frozen_string_literal: true

require_relative 'memory_store/monotonic_time'
require_relative 'memory_store/container'

class Circuitbox
  class MemoryStore
    include MonotonicTime

    def initialize(compaction_frequency: 60)
      @store = {}
      @mutex = Mutex.new
      @compaction_frequency = compaction_frequency
      @compact_after = current_second + compaction_frequency
    end

    def store(key, value, opts = {})
      @mutex.synchronize do
        @store[key] = Container.new(value: value, expiry: opts.fetch(:expires, 0))
        value
      end
    end

    def increment(key, amount = 1, opts = {})
      seconds_to_expire = opts.fetch(:expires, 0)

      @mutex.synchronize do
        existing_container = fetch_container(key)

        # reusing the existing container is a small optmization
        # to reduce the amount of objects created
        if existing_container
          existing_container.expires_after(seconds_to_expire)
          existing_container.value += amount
        else
          @store[key] = Container.new(value: amount, expiry: seconds_to_expire)
          amount
        end
      end
    end

    def load(key, _opts = {})
      @mutex.synchronize { fetch_value(key) }
    end

    def key?(key)
      @mutex.synchronize { !fetch_container(key).nil? }
    end

    def delete(key)
      @mutex.synchronize { @store.delete(key) }
    end

  private

    def fetch_container(key)
      current_time = current_second

      compact(current_time) if @compact_after < current_time

      container = @store[key]

      return unless container

      if container.expired_at?(current_time)
        @store.delete(key)
        nil
      else
        container
      end
    end

    def fetch_value(key)
      container = fetch_container(key)
      return unless container
      container.value
    end

    def compact(current_time)
      @store.delete_if { |_, value| value.expired_at?(current_time) }
      @compact_after = current_time + @compaction_frequency
    end
  end
end
