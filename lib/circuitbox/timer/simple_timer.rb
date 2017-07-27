class SimpleTimer
  def self.time(service, notifier, metric_name)
    before = Time.now.to_f
    result = yield
    after = Time.now.to_f
    notifier.metric_gauge(service, metric_name, before - after)
    result
  end
end
