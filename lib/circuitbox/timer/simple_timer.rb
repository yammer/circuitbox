class SimpleTimer
  def self.time(notifier, metric_name)
    before = Time.now.to_f
    result = yield
    after = Time.now.to_f
    notifier.metric_gauge(metric_name, before - after)
    result
  end
end