require 'test_helper'
require 'circuitbox/time_helper/real'

class TimeHelperRealTest < Minitest::Test
  class RealIncluded
    include Circuitbox::TimeHelper::Real
  end

  def test_current_second_is_instance_method_when_included
    assert_respond_to(RealIncluded.new, :current_second)
  end

  def test_current_second_can_be_directly_called
    assert_respond_to(Circuitbox::TimeHelper::Real, :current_second)
  end

  def test_current_second_uses_time_now
    now = gimme
    give(now).to_i { 5 }
    Time.expects(:now).returns(now)

    assert_equal 5, Circuitbox::TimeHelper::Real.current_second
  end
end
