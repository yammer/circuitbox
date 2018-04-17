require 'minitest/autorun'
require 'mocha/minitest'
require 'timecop'
require 'gimme'
require 'circuitbox'

DEV_NULL = (RUBY_PLATFORM =~ /mswin|mingw/ ? "NUL" : "/dev/null")

class Circuitbox
  class CircuitBreaker
    def logger
      @_dev_null_logger ||= Logger.new(DEV_NULL)
    end
  end
end
