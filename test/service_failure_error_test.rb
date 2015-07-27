require 'test_helper'

describe Circuitbox::ServiceFailureError do
  class SomeOtherError < StandardError; end;

  attr_reader :error

  before do
    begin
      raise SomeOtherError, "some other error"
    rescue => ex
      @error = ex
    end
  end

  describe '#to_s' do
    it 'includes message for wrapped exception' do
      ex = Circuitbox::ServiceFailureError.new('test', error)
      assert_equal "Circuitbox::ServiceFailureError wrapped: #{error}", ex.to_s
    end
  end

  describe '#backtrace' do
    it 'keeps the original exception backtrace' do
      ex = Circuitbox::ServiceFailureError.new('test', error)
      assert_equal error.backtrace, ex.backtrace
    end
  end

end
