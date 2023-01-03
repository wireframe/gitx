lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'gitx/version'

Gem::Specification.new do |spec|
  spec.name                  = 'gitx'
  spec.authors               = ['Ryan Sonnek']
  spec.email                 = ['ryan.sonnek@gmail.com']
  spec.description           = 'Git eXtensions for improved development workflows'
  spec.summary               = 'Utility scripts for Git to increase productivity for common operations'
  spec.homepage              = ''
  spec.license               = 'MIT'
  spec.required_ruby_version = '>= 2.7'

  spec.files                 = `git ls-files`.split($INPUT_RECORD_SEPARATOR)
  spec.executables           = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files            = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths         = ['lib']

  spec.add_runtime_dependency 'octokit'
  spec.add_runtime_dependency 'rugged', '~> 0.27.10'
  spec.add_runtime_dependency 'thor'

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'coveralls'
  spec.add_development_dependency 'pry'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec', '>= 3.0'
  spec.add_development_dependency 'rubocop'
  spec.add_development_dependency 'timecop'
  spec.add_development_dependency 'vcr'
  spec.add_development_dependency 'webmock'

  # configure gem version for continuous integration builds
  version = Gitx::VERSION
  version = "#{version}.ci.#{ENV['TRAVIS_JOB_NUMBER']}" if ENV['TRAVIS_JOB_NUMBER']
  spec.version = version
end
