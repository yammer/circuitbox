require 'test_helper'

if ENV['ACTIVE_SUPPORT']
  require 'active_support/notifications'
  require 'circuitbox/notifier/active_support'
end


class NotifierActiveSupportTest < Minitest::Test
  def test_sends_notification_on_notify
    ActiveSupport::Notifications.expects(:instrument).with("circuit_open", circuit: 'yammer')
    Circuitbox::Notifier::ActiveSupport.new.notify('yammer', :open)
  end

  def test_sends_warning_notificaiton_notify_warning
    ActiveSupport::Notifications.expects(:instrument).with("circuit_warning", { circuit: 'yammer', message: 'hello'})
    Circuitbox::Notifier::ActiveSupport.new.notify_warning('yammer', 'hello')
  end

  def test_sends_notification_on_notify_run
    ActiveSupport::Notifications.expects(:instrument).with("circuit_run", { circuit: 'yammer'})
    Circuitbox::Notifier::ActiveSupport.new.notify_run('yammer') { 'nothing' }
  end

  def test_notify_run_runs_the_block
    called = false

    Circuitbox::Notifier::ActiveSupport.new.notify_run('yammer') { called = true }

    assert called
  end
end
