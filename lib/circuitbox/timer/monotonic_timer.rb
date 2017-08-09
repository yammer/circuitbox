class MonotonicTimer
  def self.time(service, notifier, metric_name, time_unit = :milliseconds)
    before = Process.clock_gettime(Process::CLOCK_MONOTONIC, time_unit)
    result = yield
    after = Process.clock_gettime(Process::CLOCK_MONOTONIC, time_unit)
    notifier.metric_gauge(service, metric_name, after - before)
    result
  end
end
