require 'English'

module Thegarage
  module Gitx
    class Runner
      attr_accessor :shell, :options

      def initialize(shell, options = {})
        @shell = shell
        @options = options
      end

      # execute a shell command and raise an error if non-zero exit code is returned
      # return the string output from the command
      def run_cmd(cmd, options = {})
        shell.say "$ #{cmd}"
        output = `#{cmd}`
        success = $CHILD_STATUS.to_i == 0
        fail "#{cmd} failed" unless success || options[:allow_failure]
        output
      end
    end
  end
end
