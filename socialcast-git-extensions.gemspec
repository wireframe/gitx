# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "socialcast-git-extensions/version"

Gem::Specification.new do |s|
  s.name        = "socialcast-git-extensions"
  s.version     = Socialcast::Gitx::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Ryan Sonnek"]
  s.email       = ["ryan@socialcast.com"]
  s.homepage    = "http://github.com/socialcast/socialcast-git-extensions"
  s.summary     = %q{git extension scripts for socialcast workflow}
  s.description = %q{GIT it done!}

  s.rubyforge_project = "socialcast-git-extensions"

  s.add_runtime_dependency(%q<grit>, [">= 0"])
  s.add_runtime_dependency(%q<git_remote_branch>, [">= 0"])
  s.add_runtime_dependency(%q<socialcast>, [">= 1.1.4"])
  s.add_runtime_dependency(%q<rest-client>, [">= 1.4.0"])
  s.add_runtime_dependency(%q<json_pure>, [">= 0"])
  s.add_runtime_dependency(%q<thor>, [">= 0"])
  s.add_development_dependency(%q<rake>, ["0.9.2.2"])
  s.add_development_dependency "rspec", '>= 2.11.0'
  s.add_development_dependency "pry", '>= 0'
  s.add_development_dependency "webmock", '>= 0'

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end
