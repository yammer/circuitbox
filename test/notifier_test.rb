require 'test_helper'
require 'circuitbox/notifier'

describe Circuitbox::Notifier do
  describe '#initialize' do
    subject { Circuitbox::Notifier }

    it 'need at least the service parameter' do
      proc { subject.new }.must_raise ArgumentError
      subject.new(:a_service).must_be_instance_of(Circuitbox::Notifier)
    end
  end
end

describe Circuitbox::NullNotifier do
  subject { Circuitbox::NullNotifier.new(:yammer, 12) }

  it 'respond to .notify' do
    assert subject.respond_to?(:notify)
  end

  it 'respond to .notify_warning' do
    assert subject.respond_to?(:notify_warning)
  end

  it 'respond to .metric_gauge' do
    assert subject.respond_to?(:metric_gauge)
  end
end
