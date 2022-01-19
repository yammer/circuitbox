require 'test_helper'

if ENV['ACTIVE_SUPPORT']
  require 'active_support'
  require 'active_support/notifications'
  require 'circuitbox/notifier/active_support'
end


class NotifierActiveSupportTest < Minitest::Test
  def setup
    @notifier = Circuitbox::Notifier::ActiveSupport.new
  end

  def test_sends_notification_on_notify
    ActiveSupport::Notifications.expects(:instrument).with('open.circuitbox', circuit: 'yammer')
    @notifier.notify('yammer', :open)
  end

  def test_sends_warning_notificaiton_notify_warning
    ActiveSupport::Notifications.expects(:instrument).with('warning.circuitbox', { circuit: 'yammer', message: 'hello'})
    @notifier.notify_warning('yammer', 'hello')
  end

  def test_sends_notification_on_notify_run
    ActiveSupport::Notifications.expects(:instrument).with('run.circuitbox', { circuit: 'yammer'})
    @notifier.notify_run('yammer') { 'nothing' }
  end

  def test_notify_run_runs_the_block
    called = false

    @notifier.notify_run('yammer') { called = true }

    assert called
  end
end
