![Build Status](https://travis-ci.org/yammer/circuitbox.svg)

# Circuitbox

Circuitbox is a Ruby circuit breaker gem. It protects your application from failures of it's service dependencies. It wraps calls to external services and monitors for failures in one minute intervals. Once more than 10 requests have been made with a 50% failure rate, Circuitbox stops sending requests to that failing service for one minute. This helps your application gracefully degrade.
Resources about the circuit breaker pattern:
* [http://martinfowler.com/bliki/CircuitBreaker.html](http://martinfowler.com/bliki/CircuitBreaker.html)
* [https://github.com/Netflix/Hystrix/wiki/How-it-Works#CircuitBreaker](https://github.com/Netflix/Hystrix/wiki/How-it-Works#CircuitBreaker)

## Usage

```ruby
Circuitbox[:your_service] do
  Net::HTTP.get URI('http://example.com/api/messages')
end
```

Circuitbox will return nil for failed requests and open circuits.
If your HTTP client has it's own conditions for failure, you can pass an `exceptions` option.

```ruby
class ExampleServiceClient
  def circuit
    Circuitbox.circuit(:yammer, exceptions: [Zephyr::FailedRequest])
  end

  def http_get
    circuit.run do
      Zephyr.new("http://example.com").get(200, 1000, "/api/messages")
    end
  end
end
```

Using the `run!` method will throw an exception when the circuit is open or the underlying service fails.

```ruby
  def http_get
    circuit.run! do
      Zephyr.new("http://example.com").get(200, 1000, "/api/messages")
    end
  end
```


## Configuration

```ruby
class ExampleServiceClient
  def circuit
    Circuitbox.circuit(:your_service, {
      exceptions:       [YourCustomException],

      # seconds the circuit stays open once it has passed the error threshold
      sleep_window:     300,

      # number of requests within 1 minute before it calculates error rates
      volume_threshold: 10,

      # exceeding this rate will open the circuit
      error_threshold:  50,

      # seconds before the circuit times out
      timeout_seconds:  1
    })
  end
end
```

You can also pass a Proc as an option value which will evaluate each time the circuit breaker is used. This lets you configure the circuit breaker without having to restart the processes.

```ruby
Circuitbox.circuit(:yammer, {
  sleep_window: Proc.new { Configuration.get(:sleep_window) }
})
```

## Monitoring & Statistics

You can also run `rake circuits:stats SERVICE={service_name}` to see successes, failures and opened circuits.
Add `PARTITION={partition_key}` to see the circuit for a particular partition.
The stats are aggregated into 1 minute intervals.

## Notifications

circuitbox use ActiveSupport Notifications.

Usage example:

**Log on circuit open/close:**

```ruby
class CircuitOpenException    < StandardError ; end

ActiveSupport::Notifications.subscribe('circuit_open') do |name, start, finish, id, payload|
  circuit_name = payload[:circuit]
  Rails.logger.warning("Open circuit for: #{circuit_name}")
end
ActiveSupport::Notifications.subscribe('circuit_close') do |name, start, finish, id, payload|
  circuit_name = payload[:circuit]
  Rails.logger.info("Close circuit for: #{circuit_name}")
end
````

**generate metrics:**

```ruby
$statsd = Statsd.new 'localhost', 9125

ActiveSupport::Notifications.subscribe('circuit_gauge') do |name, start, finish, id, payload|
  circuit_name = payload[:circuit]
  gauge        = payload[:gauge]
  value        = payload[:value]
  metrics_key  = "circuitbox.circuit.#{circuit_name}.#{gauge}"

  $statsd.gauge(metrics_key, value)
end
```

`payload[:gauge]` can be:

- `failure_count`
- `success_count`
- `error_rate`

**warnings:**
in case of misconfiguration, circuitbox will fire a circuitbox_warning
notification.

```ruby
ActiveSupport::Notifications.subscribe('circuit_warning') do |name, start, finish, id, payload|
  circuit_name = payload[:circuit]
  warning      = payload[:message]
  Rails.logger.warning("#{circuit_name} - #{warning}")
end

```

## Faraday

Circuitbox ships with [Faraday HTTP client](https://github.com/lostisland/faraday) middleware.

```ruby
require 'faraday'
require 'circuitbox/faraday_middleware'

conn = Faraday.new(:url => "http://example.com") do |c|
  c.use Circuitbox::FaradayMiddleware
end

response = conn.get("/api")
if response.success?
  # success
else
  # failure or open circuit
end
```

By default the Faraday middleware returns a `503` response when the circuit is
open, but this as many other things can be configured via middleware options

* `exceptions` pass a list of exceptions for the Circuitbreaker to catch,
  defaults to Timeout and Request failures

```ruby
c.use Circuitbox::FaradayMiddleware, exceptions: [Faraday::Error::TimeoutError]
```

* `default_value` value to return for open circuits, defaults to 503 response
  wrapping the original response given by the service and stored as
  `original_response` property of the returned 503, this can be overwritten
  either with a static value or a `lambda` which is passed the
  original_response.

```ruby
c.use Circuitbox::FaradayMiddleware, default_value: lambda { |response| ... }
```

* `identifier` circuit id, defaults to request url

```ruby
c.use Circuitbox::FaradayMiddleware, identifier: "service_name_circuit"
```

* `circuit_breaker_run_options` options passed to the circuit run method, see
  the main circuitbreaker for those.

```ruby
conn.get("/api", circuit_breaker_run_options: {})
```

* `circuit_breaker_options` options to initialize the circuit with defaults to
  `{ volume_threshold: 10, exceptions: Circuitbox::FaradayMiddleware::DEFAULT_EXCEPTIONS }`

```ruby
c.use Circuitbox::FaradayMiddleware, circuit_breaker_options: {}
```

* `open_circuit` lambda determining what response is considered a failure, 
  counting towards the opening of the circuit

```ruby
c.use Circuitbox::FaradayMiddleware, open_circuit: lambda { |response| response.status >= 500 }
```

## TODO
* ~~Fix Faraday integration to return a Faraday response object~~
* Split stats into it's own repository
* ~~Circuit Breaker should raise an exception by default instead of returning nil~~
* Refactor to use single state variable
* Fix the partition hack
* Integrate with Breakerbox/Hystrix

## Installation

Add this line to your application's Gemfile:

    gem 'circuitbox'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install circuitbox

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
