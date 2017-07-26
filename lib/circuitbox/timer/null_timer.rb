class NullTimer
  def self.time(service, notifier, metric_name)
    yield
  end
end
