require "thegarage/gitx/version"
require 'thegarage/gitx/version'
require 'thegarage/gitx/string_extensions'
require 'thegarage/gitx/git'
require 'thegarage/gitx/github'


module Thegarage
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
