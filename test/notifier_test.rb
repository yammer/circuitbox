require 'test_helper'
require 'circuitbox/notifier'
require 'active_support/notifications'

describe Circuitbox::Notifier do
  it "sends an ActiveSupport::Notification" do
    ActiveSupport::Notifications.expects(:instrument).with("circuit_open", circuit: :yammer)
    Circuitbox::Notifier.notify(:open, :yammer)
  end
end