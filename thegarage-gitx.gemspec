# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'thegarage/gitx/version'

Gem::Specification.new do |spec|
  spec.name          = "thegarage-gitx"
  spec.version       = Thegarage::Gitx::VERSION
  spec.authors       = ["Ryan Sonnek"]
  spec.email         = ["ryan.sonnek@gmail.com"]
  spec.description   = %q{TODO: Write a gem description}
  spec.summary       = %q{TODO: Write a gem summary}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "grit"
  spec.add_runtime_dependency "rest-client", ">= 1.4.0"
  spec.add_runtime_dependency "thor"

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec", '>= 2.11.0'
  spec.add_development_dependency "pry", '>= 0'
  spec.add_development_dependency "webmock", '>= 0'
end
