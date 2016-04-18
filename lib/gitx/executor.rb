require 'open3'

module Gitx
  class Executor
    ExecutionError = Class.new(StandardError)

    # execute a shell command and raise an error if non-zero exit code is returned
    # return the string output from the command
    # block argument is passed all output from the executed thread
    def execute(*cmd)
      yield "$ #{cmd.join(' ')}" if block_given?
      output = ''

      Open3.popen2e(*cmd) do |_stdin, stdout_err, wait_thread|
        loop do
          line = stdout_err.gets
          break unless line
          output << line
          yield line if block_given?
        end

        exit_status = wait_thread.value
        fail ExecutionError, "#{cmd.join(' ')} failed" unless exit_status.success?
      end
      output
    end
  end
end
