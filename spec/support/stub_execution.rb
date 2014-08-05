# protip to prevent execution of shell commands during testsuite
# see http://stackoverflow.com/questions/1628586/mock-system-call-in-ruby
module Kernel
  def `(cmd)
    puts "stubbing execution within tests of command: #{cmd}"
  end
end
