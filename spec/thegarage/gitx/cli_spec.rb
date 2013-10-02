require 'spec_helper'

describe Thegarage::Gitx::CLI do
  # stub methods on cli
  class Thegarage::Gitx::CLI
    class << self
      attr_accessor :stubbed_executed_commands
    end
    private
    # stub out command execution and record commands for test inspection
    def run_cmd(cmd, options={})
      self.class.stubbed_executed_commands << cmd
      ''
    end
    # stub branch to always be a known branch
    def current_branch
      'FOO'
    end
    # stub current user to always be known
    def current_user
      'wireframe'
    end
  end

  before do
    Thegarage::Gitx::CLI.stubbed_executed_commands = []
  end

  describe '#update' do
    before do
      Thegarage::Gitx::CLI.start ['update']
    end
    it 'should run expected commands' do
      Thegarage::Gitx::CLI.stubbed_executed_commands.should == [
        'git pull origin FOO',
        'git pull origin master',
        'git push origin HEAD'
      ]
    end
  end

  describe '#integrate' do
    context 'when target branch is ommitted' do
      before do
        Thegarage::Gitx::CLI.start ['integrate']
      end
      it 'should default to staging' do
        Thegarage::Gitx::CLI.stubbed_executed_commands.should == [
          "git pull origin FOO",
          "git pull origin master",
          "git push origin HEAD",
          "git branch -D staging",
          "git fetch origin",
          "git checkout staging",
          "git pull . FOO",
          "git push origin HEAD",
          "git checkout FOO",
          "git checkout FOO"
        ]
      end
    end
    context 'when target branch == prototype' do
      before do
        Thegarage::Gitx::CLI.start ['integrate', 'prototype']
      end
      it 'should run expected commands' do
        Thegarage::Gitx::CLI.stubbed_executed_commands.should == [
          "git pull origin FOO",
          "git pull origin master",
          "git push origin HEAD",
          "git branch -D prototype",
          "git fetch origin",
          "git checkout prototype",
          "git pull . FOO",
          "git push origin HEAD",
          "git checkout FOO",
          "git checkout FOO"
        ]
      end
    end
    context 'when target branch != staging || prototype' do
      it 'should raise an error' do
        lambda {
          Thegarage::Gitx::CLI.start ['integrate', 'asdfasdfasdf']
        }.should raise_error(/Only aggregate branches are allowed for integration/)
      end
    end
  end

  describe '#release' do
    context 'when user rejects release' do
      before do
        Thegarage::Gitx::CLI.any_instance.should_receive(:yes?).and_return(false)
        Thegarage::Gitx::CLI.start ['release']
      end
      it 'should only run update commands' do
        Thegarage::Gitx::CLI.stubbed_executed_commands.should == [
          "git pull origin FOO",
          "git pull origin master",
          "git push origin HEAD"
        ]
      end
    end
    context 'when user confirms release' do
      before do
        Thegarage::Gitx::CLI.any_instance.should_receive(:yes?).and_return(true)
        Thegarage::Gitx::CLI.start ['release']
      end
      it 'should run expected commands' do
        Thegarage::Gitx::CLI.stubbed_executed_commands.should == [
          "git pull origin FOO",
          "git pull origin master",
          "git push origin HEAD",
          "git checkout master",
          "git pull origin master",
          "git pull . FOO",
          "git push origin HEAD",
          "git branch -D staging",
          "git fetch origin",
          "git checkout staging",
          "git pull . master",
          "git push origin HEAD",
          "git checkout master",
          "git checkout master",
          "git pull",
          "git remote prune origin"
        ]
      end
    end
  end

  describe '#nuke' do
    context 'when target branch == prototype and --destination == master' do
      before do
        prototype_branches = %w( dev-foo dev-bar )
        master_branches = %w( dev-foo )
        Thegarage::Gitx::CLI.any_instance.should_receive(:branches).and_return(prototype_branches, master_branches, prototype_branches, master_branches)
        Thegarage::Gitx::CLI.any_instance.should_receive(:yes?).and_return(false)
        Thegarage::Gitx::CLI.start ['nuke', 'prototype', '--destination', 'master']
      end
      it 'should run expected commands' do
        Thegarage::Gitx::CLI.stubbed_executed_commands.should == [
          "git checkout master",
          "git branch -D prototype",
          "git push origin --delete prototype",
          "git checkout -b prototype build-master-2013-10-01-01",
          "git push origin prototype",
          "git branch --set-upstream prototype origin/prototype",
          "git checkout master"
        ]
      end
    end
    context 'when target branch == staging and --destination == staging' do
      before do
        Thegarage::Gitx::CLI.any_instance.should_receive(:yes?).and_return(false)
        Thegarage::Gitx::CLI.start ['nuke', 'staging', '--destination', 'staging']
      end
      it 'should run expected commands' do
        Thegarage::Gitx::CLI.stubbed_executed_commands.should == [
          "git checkout master",
          "git branch -D staging",
          "git push origin --delete staging",
          "git checkout -b staging build-staging-2013-10-02-02",
          "git push origin staging",
          "git branch --set-upstream staging origin/staging",
          "git checkout master"
        ]
      end
    end
    context 'when target branch == prototype and destination prompt == nil' do
      before do
        Thegarage::Gitx::CLI.any_instance.should_receive(:ask).and_return('')
        Thegarage::Gitx::CLI.any_instance.should_receive(:yes?).and_return(false)
        Thegarage::Gitx::CLI.start ['nuke', 'prototype']
      end
      it 'defaults to prototype and should run expected commands' do
        Thegarage::Gitx::CLI.stubbed_executed_commands.should == [
          "git checkout master",
          "git branch -D prototype",
          "git push origin --delete prototype",
          "git checkout -b prototype build-prototype-2013-10-02-03",
          "git push origin prototype",
          "git branch --set-upstream prototype origin/prototype",
          "git checkout master"
        ]
      end
    end
    context 'when target branch == prototype and destination prompt = master' do
      before do
        Thegarage::Gitx::CLI.any_instance.should_receive(:ask).and_return('master')
        Thegarage::Gitx::CLI.any_instance.should_receive(:yes?).and_return(false)
        Thegarage::Gitx::CLI.start ['nuke', 'prototype']
      end
      it 'should run expected commands' do
        Thegarage::Gitx::CLI.stubbed_executed_commands.should == [
          "git checkout master",
          "git branch -D prototype",
          "git push origin --delete prototype",
          "git checkout -b prototype build-master-2013-10-01-01",
          "git push origin prototype",
          "git branch --set-upstream prototype origin/prototype",
          "git checkout master"
        ]
      end
    end
    context 'when target branch != staging || prototype' do
      it 'should raise error' do
        lambda {
          Thegarage::Gitx::CLI.any_instance.should_receive(:ask).and_return('master')
          Thegarage::Gitx::CLI.any_instance.should_receive(:yes?).and_return(false)
          Thegarage::Gitx::CLI.start ['nuke', 'asdfasdf']
        }.should raise_error /Only aggregate branches are allowed to be reset/
      end
    end
    context 'when user does not confirm nuking the target branch' do
      before do
        Thegarage::Gitx::CLI.any_instance.should_receive(:ask).and_return('master')
        Thegarage::Gitx::CLI.any_instance.should_receive(:yes?).and_return(false)
        Thegarage::Gitx::CLI.start ['nuke', 'prototype']
      end
      it 'should run expected commands' do
        Thegarage::Gitx::CLI.stubbed_executed_commands.should == [
          "git fetch --tags"
        ]
      end
    end
  end

  describe '#reviewrequest' do
    context 'when description != null' do
      before do
        stub_request(:post, "https://api.github.com/repos/thegarage/thegarage-gitx/pulls").
          to_return(:status => 200, :body => %q({"html_url": "http://github.com/repo/project/pulls/1"}), :headers => {})

        Thegarage::Gitx::CLI.start ['reviewrequest', '--description', 'testing']
      end
      it 'should create github pull request' do end # see expectations
      it 'should run expected commands' do
        Thegarage::Gitx::CLI.stubbed_executed_commands.should == [
          "git pull origin FOO",
          "git pull origin master",
          "git push origin HEAD"
        ]
      end
    end
  end
end
