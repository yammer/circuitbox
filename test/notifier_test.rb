require 'test_helper'
require 'circuitbox/notifier'
require 'active_support/notifications'


class NotifierTest < Minitest::Test
  def test_sends_notification_on_notify
    ActiveSupport::Notifications.expects(:instrument).with("circuit_open", circuit: 'yammer:12')
    Circuitbox::Notifier.new(:yammer, 12).notify(:open)
  end

  def test_sends_warning_notificaiton_notify_warning
    ActiveSupport::Notifications.expects(:instrument).with("circuit_warning", { circuit: 'yammer:12', message: 'hello'})
    Circuitbox::Notifier.new(:yammer, 12).notify_warning('hello')
  end

  def test_sends_metric_as_notification
    ActiveSupport::Notifications.expects(:instrument).with("circuit_gauge", { circuit: 'yammer:12', gauge: 'ratio', value: 12})
    Circuitbox::Notifier.new(:yammer, 12).metric_gauge(:ratio, 12)
  end
end
