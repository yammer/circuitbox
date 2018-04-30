unless ENV['ACTIVE_SUPPORT']
  exclude :test_sends_notification_on_notify, "Uses Activesupport"
  exclude :test_sends_warning_notificaiton_notify_warning, "Uses Activesupport"
  exclude :test_sends_metric_as_notification, "Uses Activesupport"
end
