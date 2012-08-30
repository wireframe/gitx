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
    Socialcast::Gitx::CLI.any_instance.stub(:current_branch).and_return('FOO')
  end

  describe '#update' do
    before do
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

  describe '#integrate' do
    context 'when target branch is ommitted' do
      before do
        @script = Socialcast::Gitx::CLI.new
        @script.invoke :integrate
      end
      it 'should default to prototype' do
        Socialcast::Gitx::CLI.stubbed_executed_commands.should == [
          "git pull origin FOO",
          "git pull origin master",
          "git push origin HEAD",
          "git remote prune origin",
          "git remote prune origin",
          "git checkout prototype",
          "git pull . FOO",
          "git push origin HEAD",
          "git checkout FOO",
          "git checkout FOO"
        ]
      end
    end
    context 'when target branch == prototype' do
      before do
        @script = Socialcast::Gitx::CLI.new
        @script.invoke :integrate, ['prototype']
      end
      it 'should run expected commands' do
        Socialcast::Gitx::CLI.stubbed_executed_commands.should == [
          "git pull origin FOO",
          "git pull origin master",
          "git push origin HEAD",
          "git remote prune origin",
          "git remote prune origin",
          "git checkout prototype",
          "git pull . FOO",
          "git push origin HEAD",
          "git checkout FOO",
          "git checkout FOO"
        ]
      end
    end
    context 'when target branch == staging' do
      before do
        @script = Socialcast::Gitx::CLI.new
        @script.invoke :integrate, ['staging']
      end
      it 'should run expected commands' do
        Socialcast::Gitx::CLI.stubbed_executed_commands.should == [
          "git pull origin FOO",
          "git pull origin master",
          "git push origin HEAD",
          "git remote prune origin",
          "git remote prune origin",
          "git checkout staging",
          "git pull . FOO",
          "git push origin HEAD",
          "git checkout FOO",
          "git remote prune origin",
          "git checkout prototype",
          "git pull . staging",
          "git push origin HEAD",
          "git checkout staging",
          "git checkout FOO"
        ]
      end
    end
    context 'when target branch != staging || prototype' do
      it 'should raise an error' do
        @script = Socialcast::Gitx::CLI.new
        lambda { @script.invoke :integrate, ['asdfasdf'] }.should raise_error(/Only aggregate branches are allowed for integration/)
      end
    end
  end
end
