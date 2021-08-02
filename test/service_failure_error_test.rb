require 'test_helper'

class ServiceFailureErrorTest < Minitest::Test
  class SomeOtherError < StandardError; end;

  attr_reader :error

  def setup
    raise SomeOtherError.new("some other error")
  rescue SomeOtherError => e
    @error = e
  end

  def test_includes_the_message_of_the_wrapped_exception
    ex = Circuitbox::ServiceFailureError.new('test', error)
    assert_equal "Circuitbox::ServiceFailureError (original: #{error})", ex.to_s
  end

  def test_keeps_the_original_backtrace
    ex = Circuitbox::ServiceFailureError.new('test', error)
    assert_equal error.backtrace, ex.backtrace
  end
end
