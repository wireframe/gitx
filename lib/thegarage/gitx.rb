require 'thegarage/gitx/version'
require 'thegarage/gitx/string_extensions'
require 'thegarage/gitx/git'
require 'thegarage/gitx/github'


module Thegarage
  module Gitx
    BASE_BRANCH = 'master'

    private

    # execute a shell command and raise an error if non-zero exit code is returned
    # return the string output from the command
    def run_cmd(cmd, options = {})
      say "\n$ "
      say cmd.gsub("'", ''), :red
      output = `#{cmd}`
      success = !!$?.to_i
      raise "#{cmd} failed" unless success || options[:allow_failure]
      output
    end
  end
end
