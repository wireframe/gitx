# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'gitx/version'

Gem::Specification.new do |spec|
  spec.name          = 'gitx'
  spec.version       = Gitx::VERSION
  spec.authors       = ['Ryan Sonnek']
  spec.email         = ['ryan.sonnek@gmail.com']
  spec.description   = 'Git eXtensions for improved development workflow'
  spec.summary       = 'Utility scripts for Git to increase productivity for common operations'
  spec.homepage      = ''
  spec.license       = 'MIT'

  spec.files         = `git ls-files`.split($INPUT_RECORD_SEPARATOR)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_runtime_dependency 'rugged', '~> 0.21.0'
  spec.add_runtime_dependency 'thor'
  spec.add_runtime_dependency 'octokit'

  spec.add_development_dependency 'bundler', '~> 1.3'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'pry', '>= 0'
  spec.add_development_dependency 'webmock', '>= 0'
  spec.add_development_dependency 'timecop', '~> 0.7.0'
  spec.add_development_dependency 'vcr'
  spec.add_development_dependency 'guard'
  spec.add_development_dependency 'guard-rspec'
  spec.add_development_dependency 'coveralls'
  spec.add_development_dependency 'terminal-notifier'
  spec.add_development_dependency 'terminal-notifier-guard'
  spec.add_development_dependency 'rubocop'
end
