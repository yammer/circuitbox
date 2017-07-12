class MonotonicTimer
  def self.time(notifier, metric_name, time_unit = :milliseconds)
    before = Process.clock_gettime(Process::CLOCK_MONOTONIC, time_unit)
    result = yield
    after = Process.clock_gettime(Process::CLOCK_MONOTONIC, time_unit)
    notifier.metric_gauge(metric_name, before - after)
    result
  end
end