# frozen_string_literal: true

require_relative 'memory_store'
require_relative 'timer'
require_relative 'notifier/active_support'
require_relative 'notifier/null'

class Circuitbox
  module Configuration
    attr_writer :default_circuit_store,
                :default_notifier,
                :default_timer,
                :default_logger

    def self.extended(base)
      base.instance_eval do
        @cached_circuits_mutex = Mutex.new
        @cached_circuits = {}

        # preload circuit_store because it has no other dependencies
        default_circuit_store
      end
    end

    def configure
      yield self
      clear_cached_circuits!
      nil
    end

    def default_circuit_store
      @default_circuit_store ||= MemoryStore.new
    end

    def default_notifier
      @default_notifier ||= if defined?(ActiveSupport::Notifications)
                              Notifier::ActiveSupport.new
                            else
                              Notifier::Null.new
                            end
    end

    def default_logger
      @default_logger ||= if defined?(Rails)
                            Rails.logger
                          else
                            Logger.new($stdout)
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
