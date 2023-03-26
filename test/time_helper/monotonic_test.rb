require 'test_helper'
require 'circuitbox/time_helper/monotonic'

class TimeHelperMonotonicTest < Minitest::Test
  class MonotonicIncluded
    include Circuitbox::TimeHelper::Monotonic
  end

  def test_current_second_is_instance_method_when_included
    assert_respond_to(MonotonicIncluded.new, :current_second)
  end

  def test_current_second_can_be_directly_called
    assert_respond_to(Circuitbox::TimeHelper::Monotonic, :current_second)
  end

  def test_current_second_uses_the_systems_monotonic_clock
    Process.expects(:clock_gettime).with(Process::CLOCK_MONOTONIC, :second)

    Circuitbox::TimeHelper::Monotonic.current_second
  end
end
