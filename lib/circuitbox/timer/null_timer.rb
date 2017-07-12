class NullTimer
  def self.time(notifier, metric_name)
    yield
  end
end