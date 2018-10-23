# frozen-string-literal: true

require_relative 'memory_store/compactor'
require_relative 'memory_store/container'

class Circuitbox
  class MemoryStore
    include MonotonicTime

    def initialize(compaction_frequency: 60)
      @store = {}
      @mutex = Mutex.new
      @compactor = Compactor.new(store: @store, frequency: compaction_frequency)
    end

    def store(key, value, opts = {})
      @mutex.synchronize do
        @store[key] = Container.new(value: value, expiry: opts.fetch(:expires, 0))
        value
      end
    end

    def increment(key, amount = 1, opts = {})
      @mutex.synchronize do
        seconds_to_expire = opts.fetch(:expires, 0)
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
      @compactor.run

      container = @store[key]

      return unless container

      if container.expired?
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
  end
end
