# frozen_string_literal: true

require_relative 'memory_store'
require_relative 'notifier/active_support'
require_relative 'notifier/null'

class Circuitbox
  module Configuration
    attr_writer :default_circuit_store,
                :default_notifier

    def self.extended(base)
      base.instance_eval do
        @cached_circuits_mutex = Mutex.new
        @cached_circuits = {}

        # preload circuit_store because it has no other dependencies
        default_circuit_store
      end
    end

    # Configure Circuitbox's defaults
    # After configuring the cached circuits are cleared
    #
    # @yieldparam [Circuitbox::Configuration] Circuitbox configuration
    #
    def configure
      yield self
      clear_cached_circuits!
      nil
    end

    # Circuit store used by circuits that are not configured with a specific circuit store
    # Defaults to Circuitbox::MemoryStore
    #
    # @return [Circuitbox::MemoryStore, Moneta] Circuit store
    def default_circuit_store
      @default_circuit_store ||= MemoryStore.new
    end

    # Notifier used by circuits that are not configured with a specific notifier.
    # If ActiveSupport::Notifications is defined it defaults to Circuitbox::Notifier::ActiveSupport
    # Otherwise it defaults to Circuitbox::Notifier::Null
    #
    # @return [Circuitbox::Notifier::ActiveSupport, Circuitbox::Notifier::Null] Notifier
    def default_notifier
      @default_notifier ||= if defined?(ActiveSupport::Notifications)
                              Notifier::ActiveSupport.new
                            else
                              Notifier::Null.new
                            end
    end

    private

    def find_or_create_circuit_breaker(service_name, options)
      @cached_circuits_mutex.synchronize do
        @cached_circuits[service_name] ||= CircuitBreaker.new(service_name, options)
      end
    end

    def clear_cached_circuits!
      @cached_circuits_mutex.synchronize { @cached_circuits = {} }
    end
  end
end
