require 'spec_helper'

describe Socialcast::Gitx::CLI do
  # stub methods on cli
  class Socialcast::Gitx::CLI
    class << self
      attr_accessor :stubbed_executed_commands
    end
    private
    # stub out command execution and record commands for test inspection
    def run_cmd(cmd)
      self.class.stubbed_executed_commands << cmd
    end
  end

  before do
    Socialcast::Gitx::CLI.stubbed_executed_commands = []
  end

  describe '#update' do
    context 'with a basic message' do
      before do
        Socialcast::Gitx::CLI.any_instance.should_receive(:current_branch).and_return('FOO')
        @script = Socialcast::Gitx::CLI.new
        @script.invoke :update
      end
      it 'should run expected commands' do
        Socialcast::Gitx::CLI.stubbed_executed_commands.should == [
          'git pull origin FOO',
          'git pull origin master',
          'git push origin HEAD',
          'git remote prune origin'
        ]
      end
    end
  end
end
