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

  def test_notify_run_accepts_one_argument_and_block
    @notifier.notify_run('first') { }
  end

  def test_notify_run_runs_the_block
    called = false

    @notifier.notify_run('something') { called = true }

    assert called
  end
end
