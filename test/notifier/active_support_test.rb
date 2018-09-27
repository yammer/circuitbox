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

  def test_sends_metric_as_notification
    ActiveSupport::Notifications.expects(:instrument).with("circuit_gauge", { circuit: 'yammer', gauge: 'ratio', value: 12})
    Circuitbox::Notifier::ActiveSupport.new.metric_gauge('yammer', 'ratio', 12)
  end
end
