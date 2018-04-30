# frozen_string_literal: true

require_relative '../test_helper'
require 'circuitbox/notifier/null'

class NotifierNullTest < Minitest::Test
  def setup
    @notifier = Circuitbox::Notifier::Null.new
  end

  def test_notify_accepts_two_arguments
    @notifier.notify('first', 'second')
  end

  def test_notify_warning_accepts_two_arguments
    @notifier.notify_warning('first', 'second')
  end

  def test_metric_gauge_accepts_three_arguments
    @notifier.metric_gauge('first', 'second', 'third')
  end
end
