## Change log
### v2.0.0 (unreleased)
- Remove timer option on a circuit, make timing (runtime metric) always enabled [\#159](https://github.com/yammer/circuitbox/pull/159)
- Rename execution_timer to timer and execution_time metric name to runtime [\#157](https://github.com/yammer/circuitbox/pull/157)
- Add frozen_string_literal to all files and enable lint rule for it [\#151](https://github.com/yammer/circuitbox/pull/151)
- Add linting [\#148](https://github.com/yammer/circuitbox/pull/148) [\#155](https://github.com/yammer/circuitbox/pull/155)
- Drop support for ruby 1.9.3 - 2.3. Support ruby 2.4 through 2.7 [\#66](https://github.com/yammer/circuitbox/pull/66) [\#92](https://github.com/yammer/circuitbox/pull/92) [\#123](https://github.com/yammer/circuitbox/pull/123) [\#144](https://github.com/yammer/circuitbox/pull/144) [\#148](https://github.com/yammer/circuitbox/pull/148)
- Add custom in-memory store for circuit data [\#113](https://github.com/yammer/circuitbox/pull/113) [\#124](https://github.com/yammer/circuitbox/pull/124) [\#134](https://github.com/yammer/circuitbox/pull/134)
- Significant improvements to tracking circuit state and state changes [\#117](https://github.com/yammer/circuitbox/pull/117) [\#118](https://github.com/yammer/circuitbox/pull/118)
- Remove accessing Circuitbox circuits through ```Circuitbox[]``` [\#133](https://github.com/yammer/circuitbox/pull/133)
- Faraday middleware supports faraday 1.0 [\#143](https://github.com/yammer/circuitbox/pull/143)
- Remove ```run!``` method and change ```run``` method (see upgrade guide) [\#119](https://github.com/yammer/circuitbox/pull/119) [\#126](https://github.com/yammer/circuitbox/pull/126)
- Correctly check a circuits volume threshold [\#116](https://github.com/yammer/circuitbox/pull/116)
- Stop overwriting sleep_window when it is less than time window [\#108](https://github.com/yammer/circuitbox/pull/108)
- Lower default sleep window from 300 seconds (5 minutes) to 90 seconds (1 minute 30 seconds) [\#107](https://github.com/yammer/circuitbox/pull/107)
- Remove Circuitbox's use of ruby timeout [\#106](https://github.com/yammer/circuitbox/pull/106)
- Register faraday middleware [\#104](https://github.com/yammer/circuitbox/pull/104)
- Fix undefined instance variable warnings [\#103](https://github.com/yammer/circuitbox/pull/103)
- Remove dependency on ActiveSupport [\#99](https://github.com/yammer/circuitbox/pull/99)
- Remove ability to modify most of a circuitbreaker's configuration after it's been created (recreate circuit to change configuration) [\#88](https://github.com/yammer/circuitbox/pull/88)
- Remove circuitbox parsing host from ```service_name``` if given a url [\#87](https://github.com/yammer/circuitbox/pull/87)
- Various cleanup and performance improvements [\#81](https://github.com/yammer/circuitbox/pull/81) [\#82](https://github.com/yammer/circuitbox/pull/82) [\#83](https://github.com/yammer/circuitbox/pull/83) [\#85](https://github.com/yammer/circuitbox/pull/85) [\#86](https://github.com/yammer/circuitbox/pull/86) [\#89](https://github.com/yammer/circuitbox/pull/89) [\#90](https://github.com/yammer/circuitbox/pull/90) [\#91](https://github.com/yammer/circuitbox/pull/91) [\#105](https://github.com/yammer/circuitbox/pull/105) [\#109](https://github.com/yammer/circuitbox/pull/109) [\#110](https://github.com/yammer/circuitbox/pull/110) [\#111](https://github.com/yammer/circuitbox/pull/111) [\#112](https://github.com/yammer/circuitbox/pull/112) [\#120](https://github.com/yammer/circuitbox/pull/120) [\#121](https://github.com/yammer/circuitbox/pull/121) [\#122](https://github.com/yammer/circuitbox/pull/122) [\#130](https://github.com/yammer/circuitbox/pull/130) [\#135](https://github.com/yammer/circuitbox/pull/135) [\#158](https://github.com/yammer/circuitbox/pull/158) [\#160](https://github.com/yammer/circuitbox/pull/160)
- Internal configuration rewrite [\#80](https://github.com/yammer/circuitbox/pull/80)
- Fix circuit being stuck open [\#78](https://github.com/yammer/circuitbox/pull/78)
- Add default timer configuration option [\#73](https://github.com/yammer/circuitbox/pull/73)
- Emit circuit timing notifications [\#72](https://github.com/yammer/circuitbox/pull/72)
- Readme and spelling fixes/updates [\#71](https://github.com/yammer/circuitbox/pull/71) [\#77](https://github.com/yammer/circuitbox/pull/77) [\#84](https://github.com/yammer/circuitbox/pull/84) [\#140](https://github.com/yammer/circuitbox/pull/140)
- Add ```default_notifier``` configuration option [\#68](https://github.com/yammer/circuitbox/pull/68)
- Remove circuit partitions [\#67](https://github.com/yammer/circuitbox/pull/67)

### v1.1.0
- ruby 2.2 support [\#58](https://github.com/yammer/circuitbox/pull/58)
- configurable logger [\#58](https://github.com/yammer/circuitbox/pull/58)

### v1.0.3
- fix timeout issue for default configuration, as default `:Memory` adapter does
  not natively support expires, we need to actually load it on demand.
- fix memoization of `circuit_breaker_options` not actually doing memoization in
  `excon` and `faraday` middleware.

### v1.0.2
- Fix timeout issue [\#51](https://github.com/yammer/circuitbox/issues/51)
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
- fix for issue 16, support of in_parallel requests in faraday middleware which were opening the circuit.
- deprecate the __run_option__ `:storage_key`

### v0.9
- add `run!` method to raise exception on circuit open and service

### v0.8
- Everything prior to keeping the change log
