# Circuit Notifications

Circuitbox supports sending notifications when various events occur.
The following events are sent to the notifier:

* Circuit block runs (this is where notifiers do timing)
* Circuit is skipped
* Circuit run is successful
* Circuit run is failed
* Circuit is opened
* Circuit is closed
* Circuit is not configured correctly

There are two types of notifiers built into circuitbox, null and active support.
The null notifier does not send notifications.
The active support notifier sends notifications through `ActiveSupport::Notifications`.

## Active Support Notifications

There are three different types of notification payloads which are defined below

All notifications contain `:circuit` in the payload.
The value of `:circuit` is the name of the circuit.

The first type of notifications are:

* `open.circuitbox` - Sent when the circuit moves to the open state.
* `close.circuitbox` - Sent when the circuit moves to the closed state.
* `skipped.circuitbox` - Sent when the circuit is run and in the open state.
* `success.circuitbox` - Sent when the circuit is run and the run succeeds.
* `failure.circuitbox` - Sent when the circuit is run and the run fails.

The second type of notifications are contain a `:message` in the payload, in addition to `:circuit`.
The value of `:message` is a string.

* `warning.circuitbox` - Sent when there is a misconfiguration of the circuit.

The third type of notifications can be used for timing of the circuit.
The timing is done by `ActiveSupport::Notifications`.

* `run.circuitbox` - Sent after the circuit is run.

### Examples

#### Open/Close/Skipped/Success/Failure

```ruby
ActiveSupport::Notifications.subscribe('open.circuitbox') do |*args|
  event = ActiveSupport::Notifications::Event.new(*args)
  circuit_name = event.payload[:circuit]
  Rails.logger.warn("Open circuit for: #{circuit_name}")
end

ActiveSupport::Notifications.subscribe('close.circuitbox') do |*args|
  event = ActiveSupport::Notifications::Event.new(*args)
  circuit_name = event.payload[:circuit]
  Rails.logger.info("Close circuit for: #{circuit_name}")
end
```

#### Warning

```ruby
ActiveSupport::Notifications.subscribe('warning.circuitbox') do |*args|
  event = ActiveSupport::Notifications::Event.new(*args)
  circuit_name = event.payload[:circuit]
  warning      = event.payload[:message]
  Rails.logger.warning("Circuit warning for: #{circuit_name} Message: #{warning}")
end
```

#### Timing
```ruby
ActiveSupport::Notifications.subscribe('run.circuitbox') do |*args|
  event = ActiveSupport::Notifications::Event.new(*args)
  circuit_name = event.payload[:circuit_name]
  
  Rails.logger.info("Circuit: #{circuit_name} Runtime: #{event.duration}")
end
```
