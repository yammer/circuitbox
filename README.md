# Circuitbox

[![Build Status](https://travis-ci.org/yammer/circuitbox.svg?branch=master)](https://travis-ci.org/yammer/circuitbox) [![Gem Version](https://badge.fury.io/rb/circuitbox.svg)](https://badge.fury.io/rb/circuitbox)

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

      # length of interval (in seconds) over which it calculates the error rate
      time_window:      60,

      # number of requests within `time_window` seconds before it calculates error rates
      volume_threshold: 10,

      # the store you want to use to save the circuit state so it can be
      # tracked, this needs to be Moneta compatible, and support increment
      cache: Moneta.new(:Memory)

      # exceeding this rate will open the circuit
      error_threshold:  50,

      # seconds before the circuit times out
      # if set to nil no timeout is used
      timeout_seconds:  1

      # Logger to use
      logger: Logger.new(STDOUT)
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

## Circuit Store (:cache)

Holds all the relevant data to trip the circuit if a given number of requests
fail in a specified period of time. The store is based on
[Moneta](https://github.com/minad/moneta) so there are a lot of stores to choose
from. There are some pre-requisits they need to satisfy so:

- Need to support increment, this is true for most but not all available stores.
- Need to support concurrent access if you share them. For example sharing a
  KyotoCabinet store across process fails because the store is single writer
  multiple readers, and all circuits sharing the store need to be able to write.


## Notifications

circuitbox use ActiveSupport Notifications.

Usage example:

**Log on circuit open/close:**

```ruby
class CircuitOpenException    < StandardError ; end

ActiveSupport::Notifications.subscribe('circuit_open') do |name, start, finish, id, payload|
  circuit_name = payload[:circuit]
  Rails.logger.warn("Open circuit for: #{circuit_name}")
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

### Multi process Circuits

`circuit_store` is backed by [Moneta](https://github.com/minad/moneta) which
supports multiple backends. This can be configured by passing `cache:
Moneta.new(:PStore, file: "myfile.store")` to use for example the built in
PStore ruby library for persisted store, which can be shared cross process.

Depending on your requirements different stores can make sense, see the
benchmarks and [moneta
feature](https://github.com/minad/moneta#backend-feature-matrix) matrix for
details.

```
user     system      total        real
memory:    1.440000   0.140000   1.580000 (  1.579244)
lmdb:      4.330000   3.280000   7.610000 ( 13.086398)
pstore:   23.680000   4.350000  28.030000 ( 28.094312)
daybreak:  2.270000   0.450000   2.720000 (  2.626748)
```

You can run the benchmarks yourself by running `rake benchmark`.

### Memory

An in memory store, which is local to the process. This is not threadsafe so it
is not useable with multithreaded webservers for example. It is always going to
be the fastest option if no multi-process or thread is required, like in
development on Webbrick.

This is the default.

```ruby
Circuitbox.circuit :identifier, cache: Moneta.new(:Memory)
```

### LMDB

An persisted directory backed store, which is thread and multi process safe.
depends on the `lmdb` gem. It is slower than Memory or Daybreak, but can be
used in multi thread and multi process environments like like Puma.

```ruby
require "lmdb"
Circuitbox.circuit :identifier, cache: Moneta.new(:LMDB, dir: "./", db: "mydb")
```

### PStore

An persisted file backed store, which comes with the ruby
[stdlib](http://ruby-doc.org/stdlib-2.3.0/libdoc/pstore/rdoc/PStore.html). It
has no external dependecies and works on every ruby implementation. Due to it
being file backed it is multi process safe, good for development using Unicorn.

```ruby
Circuitbox.circuit :identifier, cache: Moneta.new(:PStore, file: "db.pstore")
```

### Daybreak

Persisted, file backed key value store in pure ruby. It is process safe and
outperforms most other stores in circuitbox. This is recommended for production
use with Unicorn. It depends on the `daybreak` gem.

```ruby
require "daybreak"
Circuitbox.circuit :identifier, cache: Moneta.new(:Daybreak, file: "db.daybreak", expires: true)
```

It is important for the store to have
[expires](https://github.com/minad/moneta#backend-feature-matrix) support.

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
  with either
  * a static value
  * a `lambda` which is passed the `original_response` and `original_error`.
    `original_response` will be populated if Faraday returns an error response,
    `original_error` will be populated if an error was thrown before Faraday
    returned a response.  (It will also accept a lambda with arity 1 that is
    only passed `original_response`.  This use is deprecated and will be removed
    in the next major version.)

```ruby
c.use Circuitbox::FaradayMiddleware, default_value: lambda { |response, error| ... }
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

## CHANGELOG
### v1.1.0
- ruby 2.2 support [#58](https://github.com/yammer/circuitbox/pull/58)
- configurable logger [#58](https://github.com/yammer/circuitbox/pull/58)

### v1.0.3
- fix timeout issue for default configuration, as default `:Memory` adapter does
  not natively support expires, we need to actually load it on demand.
- fix memoization of `circuit_breaker_options` not actually doing memoization in
  `excon` and `faraday` middleware.

### v1.0.2
- Fix timeout issue [#51](https://github.com/yammer/circuitbox/issues/51)
  [sebastian-juliu](https://github.com/sebastian-julius)

### v1.0.1
- Fix Rails integration, as version 1.0.0 removed the rails tasks integration, but missed
  removing the related railtie.

### v1.0.0
- support for cross process circuitbreakers by swapping the circuitbreaker store for a
  `Moneta` supported key value store.
- Change `FaradayMiddleware` default behaviour to not open on `4xx` errors but just on `5xx`
  server errors and connection errors
- Remove stat store, which was largely unused

### v0.11.0
- fix URI require missing (https://github.com/yammer/circuitbox/pull/42 @gottfrois)
- configurable circuitbox store backend via Moneta supporting multi process circuits

### v0.10.4
- Issue #39, keep the original backtrace for the wrapped exception around when
  re-raising a Circuitbox::Error

### v0.10.3
- Circuitbox::ServiceFailureError wraps the original exception that was raised.
  The behaviour for to_s wasn't exposing this information and was returning the
  name of class "Circuitbox::ServiceFailureError". Change the behaviour for to_s
  to indicate this exception is a wrapper around the original exception.
  [sherrry](https://github.com/sherrry)

### v0.10.2
- Faraday middleware passes two arguments to the `default_value` callback, not
  just one.  First argument is still the error response from Faraday if there is
  one.  Second argument is the exception that caused the call to fail if it
  failed before Faraday returned a response.  Old behaviour is preserved if you
  pass a lambda that takes just one argument, but this is deprecated and will be
  removed in the next version of Circuitbox.
  [dwaller](https://github.com/dwaller)

### v0.10.1
- [Documentation fix](https://github.com/yammer/circuitbox/pull/29) [chiefcll](https://github.com/chiefcll)
- [Faraday middleware fix](https://github.com/yammer/circuitbox/pull/30) [chiefcll](https://github.com/chiefcll)

### v0.10
- configuration option for faraday middleware for what should be considered to open the circuit [enrico-scalavio](https://github.com/enrico-scalavino)
- fix for issue 16, support of in_parallel requests in faraday middlware which were opening the circuit.
- deprecate the __run_option__ `:storage_key`

### v0.9
- add `run!` method to raise exception on circuit open and service

### v0.8
- Everything prior to keeping the change log

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
