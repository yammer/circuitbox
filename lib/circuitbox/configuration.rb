require 'moneta'
require_relative 'timer/simple'
require_relative 'notifier'

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
      @default_circuit_store ||= Moneta.new(:Memory, expires: true, threadsafe: true)
    end

    def default_notifier
      @default_notifier ||= Notifier.new
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
