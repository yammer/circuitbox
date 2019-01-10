# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'circuitbox/version'

Gem::Specification.new do |spec|
  spec.name          = 'circuitbox'
  spec.version       = Circuitbox::VERSION
  spec.authors       = ['Fahim Ferdous', 'Matthew Shafer']
  spec.email         = ['fahimfmf@gmail.com']
  spec.summary       = 'A robust circuit breaker that manages failing external services.'
  spec.homepage      = 'https://github.com/yammer/circuitbox'
  spec.license       = 'Apache-2.0'

  spec.files = Dir['README.md', 'LICENSE', 'lib/**/*']
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 1.16'
  spec.add_development_dependency 'excon', '~> 0.62'
  spec.add_development_dependency 'faraday', '~> 0.15'
  spec.add_development_dependency 'gimme', '~> 0.5'
  spec.add_development_dependency 'minitest', '~> 5.11'
  spec.add_development_dependency 'minitest-excludes', '~> 2.0'
  spec.add_development_dependency 'mocha', '~> 1.7'
  spec.add_development_dependency 'rack', '~> 2.0'
  spec.add_development_dependency 'rake', '~> 12.0'
  spec.add_development_dependency 'timecop', '~> 0.9'
  spec.add_development_dependency 'typhoeus', '~> 1.3'
  spec.add_development_dependency 'moneta', '~> 1.0'
end
