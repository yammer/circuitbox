if Gem.loaded_specs.has_key?('activesupport')
  require 'active_support'
else
  exclude :test_sends_notification_on_notify, "Uses Activesupport"
  exclude :test_sends_warning_notificaiton_notify_warning, "Uses Activesupport"
  exclude :test_sends_notification_on_notify_run, "Uses Activesupport"
  exclude :test_notify_run_runs_the_block, "Uses Activesupport"
end
