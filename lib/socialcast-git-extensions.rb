require 'rubygems'
require 'socialcast-git-extensions/version'
require 'socialcast-git-extensions/string_ext'
require 'socialcast-git-extensions/git'
require 'socialcast-git-extensions/github'

module Socialcast
  module Gitx
    BASE_BRANCH = 'master'

    private
    # execute a shell command and raise an error if non-zero exit code is returned
    def run_cmd(cmd)
      say "\n$ "
      say cmd.gsub("'", ''), :red
      raise "#{cmd} failed" unless system cmd
    end
  end
end
