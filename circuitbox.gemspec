# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'circuitbox/version'

Gem::Specification.new do |spec|
  spec.name          = "circuitbox"
  spec.version       = Circuitbox::VERSION
  spec.authors       = ["Fahim Ferdous"]
  spec.email         = ["fferdous@yammer-inc.com"]
  spec.description   = %q{A robust circuit breaker that manages failing external services.}
  spec.summary       = %q{A robust circuit breaker that manages failing external services.}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.4"
  spec.add_development_dependency "rake"

  spec.add_dependency "activesupport"
  spec.add_development_dependency 'bundler-yammer_gem_tasks'
end
