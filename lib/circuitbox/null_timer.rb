class NullTimer
  def initialize(time_unit = :milliseconds)
    @time_unit = time_unit
  end

  def time(notifier, metric_name)
    yield
  end
end