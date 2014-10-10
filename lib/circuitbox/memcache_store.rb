module ActiveSupport
  module Cache
    class MemcacheStore
      def initialize(cache)
        @cache = cache
      end

      def read(key, options = {})
        @cache.get(key, options)
      rescue Memcached::NotFound
        nil
      end

      def increment(key)
        @cache.incr(key)
      end

      def write(key, value, options = {})
        if expires_in = options.delete(:expires_in)
          options[:expiry] = expires_in.to_i
        end

        @cache.set(key, value, options)
      end

      def delete(key)
        @cache.delete(key)
      end
    end
  end
end