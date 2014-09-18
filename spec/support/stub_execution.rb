# protip to prevent execution of shell commands during testsuite
# see http://stackoverflow.com/questions/1628586/mock-system-call-in-ruby
module Kernel
  def execute_with_stub(cmd)
    if cmd.include?('git')
      puts "WARNING: stubbing command execution within tests of command: #{cmd}", :red
    else
      execute_without_stub(cmd)
    end
  end

  alias_method :execute_without_stub, :`
  alias_method :`, :execute_with_stub
end
