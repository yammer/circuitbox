require 'moneta'
require_relative 'timer/simple'
require_relative 'notifier'

class Circuitbox
  module Configuration
    attr_writer :default_circuit_store,
                :default_notifier,
                :default_timer

    def configure
      yield self
      clear_cached_circuits!
      nil
    end

    def default_circuit_store
      @default_circuit_store ||= Moneta.new(:Memory, expires: true)
    end

    def default_notifier
      @default_notifier ||= Notifier.new
    end

    def default_timer
      @default_timer ||= Timer::Simple.new
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
