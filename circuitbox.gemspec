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

  spec.metadata = {
    'bug_tracker_uri' => 'https://github.com/yammer/circuitbox/issues',
    'changelog_uri' => 'https://github.com/yammer/circuitbox/blob/main/CHANGELOG.md',
    'source_code_uri' => 'https://github.com/yammer/circuitbox',
    'rubygems_mfa_required' => 'true'
  }

  spec.required_ruby_version = '>= 2.6.0'

  spec.files = Dir['README.md', 'LICENSE', 'lib/**/*']
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '> 2.0'
  spec.add_development_dependency 'excon', '~> 0.71'
  spec.add_development_dependency 'faraday', '>= 0.17'
  spec.add_development_dependency 'gimme', '~> 0.5'
  spec.add_development_dependency 'minitest', '~> 5.14'
  spec.add_development_dependency 'minitest-excludes', '~> 2.0'
  spec.add_development_dependency 'mocha', '~> 1.12'
  spec.add_development_dependency 'moneta', '~> 1.0'
  spec.add_development_dependency 'rack', '~> 2.0'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'timecop', '~> 0.9'
  spec.add_development_dependency 'typhoeus', '~> 1.4'
  spec.add_development_dependency 'webrick', '~> 1.7'
  spec.add_development_dependency 'yard', '~> 0.9.26'
end
