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
    Socialcast::Gitx::CLI.any_instance.stub(:post)
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

  describe '#release' do
    context 'when user rejects release' do
      before do
        Socialcast::Gitx::CLI.any_instance.should_receive(:yes?).and_return(false)
        @script = Socialcast::Gitx::CLI.new
        @script.invoke :release
      end
      it 'should run no commands' do
        Socialcast::Gitx::CLI.stubbed_executed_commands.should == []
      end
    end
    context 'when user confirms release' do
      before do
        Socialcast::Gitx::CLI.any_instance.should_receive(:yes?).and_return(true)
        @script = Socialcast::Gitx::CLI.new
        @script.invoke :release
      end
      it 'should run expected commands' do
        Socialcast::Gitx::CLI.stubbed_executed_commands.should == [
          "git pull origin FOO",
          "git pull origin master",
          "git push origin HEAD",
          "git remote prune origin",
          "git remote prune origin",
          "git checkout master",
          "git pull . FOO",
          "git push origin HEAD",
          "git checkout FOO",
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
          "git checkout FOO",
          "git checkout master",
          "grb rm FOO"
        ]
      end
    end
  end

  describe '#nuke' do
    context 'when target branch == prototype and --destination == master' do
      before do
        Socialcast::Gitx::CLI.start ['nuke', 'prototype', '--destination', 'master']
      end
      it 'should run expected commands' do
        Socialcast::Gitx::CLI.stubbed_executed_commands.should == [
          "git checkout last_known_good_master",
          "git pull",
          "git branch -D prototype",
          "git push origin :prototype",
          "git checkout -b prototype",
          "grb publish prototype",
          "git checkout last_known_good_master",
          "git checkout last_known_good_master",
          "git pull",
          "git branch -D last_known_good_prototype",
          "git push origin :last_known_good_prototype",
          "git checkout -b last_known_good_prototype",
          "grb publish last_known_good_prototype",
          "git checkout last_known_good_master"
        ]
      end
    end
    context 'when target branch == staging and --destination == last_known_good_staging' do
      before do
        Socialcast::Gitx::CLI.start ['nuke', 'staging', '--destination', 'last_known_good_staging']
      end
      it 'should run expected commands' do
        Socialcast::Gitx::CLI.stubbed_executed_commands.should == [
          "git checkout last_known_good_staging",
          "git pull",
          "git branch -D staging",
          "git push origin :staging",
          "git checkout -b staging",
          "grb publish staging",
          "git checkout last_known_good_staging"
        ]
      end
    end
    context 'when target branch == prototype and destination prompt == nil' do
      before do
        Socialcast::Gitx::CLI.any_instance.should_receive(:ask).and_return('')
        Socialcast::Gitx::CLI.start ['nuke', 'prototype']
      end
      it 'defaults to last_known_good_prototype and should run expected commands' do
        Socialcast::Gitx::CLI.stubbed_executed_commands.should == [
          "git checkout last_known_good_prototype",
          "git pull",
          "git branch -D prototype",
          "git push origin :prototype",
          "git checkout -b prototype",
          "grb publish prototype",
          "git checkout last_known_good_prototype"
        ]
      end
    end
    context 'when target branch == prototype and destination prompt = master' do
      before do
        Socialcast::Gitx::CLI.any_instance.should_receive(:ask).and_return('master')
        Socialcast::Gitx::CLI.start ['nuke', 'prototype']
      end
      it 'should run expected commands' do
        Socialcast::Gitx::CLI.stubbed_executed_commands.should == [
          "git checkout last_known_good_master",
          "git pull",
          "git branch -D prototype",
          "git push origin :prototype",
          "git checkout -b prototype",
          "grb publish prototype",
          "git checkout last_known_good_master",
          "git checkout last_known_good_master",
          "git pull",
          "git branch -D last_known_good_prototype",
          "git push origin :last_known_good_prototype",
          "git checkout -b last_known_good_prototype",
          "grb publish last_known_good_prototype",
          "git checkout last_known_good_master"
        ]
      end
    end
    context 'when target branch != staging || prototype' do
      it 'should raise error' do
        lambda {
          Socialcast::Gitx::CLI.any_instance.should_receive(:ask).and_return('master')
          Socialcast::Gitx::CLI.start ['nuke', 'asdfasdf']
        }.should raise_error /Only aggregate branches are allowed to be reset/
      end
    end
  end
end
