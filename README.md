**WARNING** We just discover a bug in the actual version, preventing the circuit to open when a single request is successful. This is a major issue we are fixing in the next few days.

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

## Faraday (Caveat: Open circuits return a nil response object)

Circuitbox ships with [Faraday HTTP client](https://github.com/lostisland/faraday) middleware. 

```ruby
require 'faraday'
require 'circuitbox/faraday_middleware'

conn = Faraday::Connection.new(:url => "http://example.com") do |builder|
  builder.use Circuitbox::FaradayMiddleware
end

if response = conn.get("/api")
  # success
else
  # failure or open circuit
end
```

## TODO
* Fix Faraday integration to return a Faraday response object
* Split stats into it's own repository
* Circuit Breaker should raise an exception by default instead of returning nil
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
