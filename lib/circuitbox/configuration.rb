require_relative 'memory_store'
require_relative 'timer/monotonic'
require_relative 'timer/null'
require_relative 'timer/simple'
require_relative 'notifier/active_support'
require_relative 'notifier/null'

class Circuitbox
  module Configuration
    attr_writer :default_circuit_store,
                :default_notifier,
                :default_timer,
                :default_logger

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

    def default_timer
      @default_timer ||= Timer::Simple.new
    end

    def default_logger
      @default_logger ||= if defined?(Rails)
                            Rails.logger
                          else
                            Logger.new(STDOUT)
                          end
    end

    private

    def cached_circuits
      @cached_circuits ||= {}
    end

    def clear_cached_circuits!
      @cached_circuits = {}
    end
  end
end
