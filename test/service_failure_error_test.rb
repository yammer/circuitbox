require 'test_helper'

class ServiceFailureErrorTest < Minitest::Test
  class SomeOtherError < StandardError; end;
  
  describe 'to_s' do
    it 'includes message for wrapped exception' do
      some_error = SomeOtherError.new("some other error")
      ex = Circuitbox::ServiceFailureError.new('test', some_error)
      assert_equal "Circuitbox::ServiceFailureError wrapped: #{some_error}", ex.to_s
    end
  end
end
