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
    Socialcast::Gitx::CLI.any_instance.stub(:current_user).and_return('wireframe')
    Socialcast::Gitx::CLI.any_instance.stub(:post)
  end

  describe '#update' do
    before do
      Socialcast::Gitx::CLI.any_instance.should_not_receive(:post)
      Socialcast::Gitx::CLI.start ['update']
    end
    it 'should not post message to socialcast' do end # see expectations
    it 'should run expected commands' do
      Socialcast::Gitx::CLI.stubbed_executed_commands.should == [
        'git pull origin FOO',
        'git pull origin master',
        'git push origin HEAD'
      ]
    end
  end

  describe '#integrate' do
    context 'when target branch is ommitted' do
      before do
        Socialcast::Gitx::CLI.any_instance.should_receive(:post).with("#worklog integrating FOO into prototype #scgitx")
        Socialcast::Gitx::CLI.start ['integrate']
      end
      it 'should post message to socialcast' do end # see expectations
      it 'should default to prototype' do
        Socialcast::Gitx::CLI.stubbed_executed_commands.should == [
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
    context 'when target branch == prototype' do
      before do
        Socialcast::Gitx::CLI.any_instance.should_receive(:post).with("#worklog integrating FOO into prototype #scgitx")
        Socialcast::Gitx::CLI.start ['integrate', 'prototype']
      end
      it 'should post message to socialcast' do end # see expectations
      it 'should run expected commands' do
        Socialcast::Gitx::CLI.stubbed_executed_commands.should == [
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
    context 'when target branch == staging' do
      before do
        Socialcast::Gitx::CLI.any_instance.should_receive(:post).with("#worklog integrating FOO into staging #scgitx")
        Socialcast::Gitx::CLI.start ['integrate', 'staging']
      end
      it 'should post message to socialcast' do end # see expectations
      it 'should also integrate into prototype and run expected commands' do
        Socialcast::Gitx::CLI.stubbed_executed_commands.should == [
          "git pull origin FOO",
          "git pull origin master",
          "git push origin HEAD",
          "git branch -D staging",
          "git fetch origin",
          "git checkout staging",
          "git pull . FOO",
          "git push origin HEAD",
          "git checkout FOO",
          "git branch -D prototype",
          "git fetch origin",
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
        lambda {
          Socialcast::Gitx::CLI.start ['integrate', 'asdfasdfasdf']
        }.should raise_error(/Only aggregate branches are allowed for integration/)
      end
    end
  end

  describe '#release' do
    context 'when user rejects release' do
      before do
        Socialcast::Gitx::CLI.any_instance.should_receive(:yes?).and_return(false)
        Socialcast::Gitx::CLI.start ['release']
      end
      it 'should run no commands' do
        Socialcast::Gitx::CLI.stubbed_executed_commands.should == []
      end
    end
    context 'when user confirms release' do
      before do
        Socialcast::Gitx::CLI.any_instance.should_receive(:post).with("#worklog releasing FOO to production #scgitx")
        Socialcast::Gitx::CLI.any_instance.should_receive(:yes?).and_return(true)
        Socialcast::Gitx::CLI.start ['release']
      end
      it 'should post message to socialcast' do end # see expectations
      it 'should run expected commands' do
        Socialcast::Gitx::CLI.stubbed_executed_commands.should == [
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
        Socialcast::Gitx::CLI.any_instance.should_receive(:branches).and_return(prototype_branches, master_branches, prototype_branches, master_branches)
        Socialcast::Gitx::CLI.any_instance.should_receive(:post).with("#worklog resetting prototype branch to last_known_good_master #scgitx\n/cc @SocialcastDevelopers\n\nthe following branches were affected:\n* dev-bar")
        Socialcast::Gitx::CLI.start ['nuke', 'prototype', '--destination', 'master']
      end
      it 'should publish message into socialcast' do end # see expectations
      it 'should run expected commands' do
        Socialcast::Gitx::CLI.stubbed_executed_commands.should == [
          "git checkout master",
          "git branch -D last_known_good_master",
          "git fetch origin",
          "git checkout last_known_good_master",
          "git branch -D prototype",
          "git push origin --delete prototype",
          "git checkout -b prototype",
          "git push origin prototype",
          "git branch --set-upstream prototype origin/prototype",
          "git checkout master",
          "git checkout master",
          "git branch -D last_known_good_master",
          "git fetch origin",
          "git checkout last_known_good_master",
          "git branch -D last_known_good_prototype",
          "git push origin --delete last_known_good_prototype",
          "git checkout -b last_known_good_prototype",
          "git push origin last_known_good_prototype",
          "git branch --set-upstream last_known_good_prototype origin/last_known_good_prototype",
          "git checkout master"
        ]
      end
    end
    context 'when target branch == staging and --destination == last_known_good_staging' do
      before do
        Socialcast::Gitx::CLI.start ['nuke', 'staging', '--destination', 'last_known_good_staging']
      end
      it 'should run expected commands' do
        Socialcast::Gitx::CLI.stubbed_executed_commands.should == [
          "git checkout master",
          "git branch -D last_known_good_staging",
          "git fetch origin",
          "git checkout last_known_good_staging",
          "git branch -D staging",
          "git push origin --delete staging",
          "git checkout -b staging",
          "git push origin staging",
          "git branch --set-upstream staging origin/staging",
          "git checkout master"
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
          "git checkout master",
          "git branch -D last_known_good_prototype",
          "git fetch origin",
          "git checkout last_known_good_prototype",
          "git branch -D prototype",
          "git push origin --delete prototype",
          "git checkout -b prototype",
          "git push origin prototype",
          "git branch --set-upstream prototype origin/prototype",
          "git checkout master"
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
          "git checkout master",
          "git branch -D last_known_good_master",
          "git fetch origin",
          "git checkout last_known_good_master",
          "git branch -D prototype",
          "git push origin --delete prototype",
          "git checkout -b prototype",
          "git push origin prototype",
          "git branch --set-upstream prototype origin/prototype",
          "git checkout master",
          "git checkout master",
          "git branch -D last_known_good_master",
          "git fetch origin",
          "git checkout last_known_good_master",
          "git branch -D last_known_good_prototype",
          "git push origin --delete last_known_good_prototype",
          "git checkout -b last_known_good_prototype",
          "git push origin last_known_good_prototype",
          "git branch --set-upstream last_known_good_prototype origin/last_known_good_prototype",
          "git checkout master"
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

  describe '#reviewrequest' do
    context 'when there are no review_buddies specified' do
      before do
        Socialcast::Gitx::CLI.any_instance.stub(:config_file).and_return(Pathname(''))
      end
      context 'when description != null' do
        before do
          stub_request(:post, "https://api.github.com/repos/socialcast/socialcast-git-extensions/pulls").
            to_return(:status => 200, :body => %q({"html_url": "http://github.com/repo/project/pulls/1"}), :headers => {})

          Socialcast::Gitx::CLI.any_instance.should_receive(:post).with("#reviewrequest for FOO #scgitx\n\n/cc @SocialcastDevelopers\n\ntesting\n\n", :url => 'http://github.com/repo/project/pulls/1', :message_type => 'review_request')
          Socialcast::Gitx::CLI.start ['reviewrequest', '--description', 'testing']
        end
        it 'should create github pull request' do end # see expectations
        it 'should post socialcast message' do end # see expectations
        it 'should run expected commands' do
          Socialcast::Gitx::CLI.stubbed_executed_commands.should == [
            "git pull origin FOO",
            "git pull origin master",
            "git push origin HEAD"
          ]
        end
      end
    end

    context 'when review_buddies are specified via a /config YML file' do
      before do
        stub_request(:post, "https://api.github.com/repos/socialcast/socialcast-git-extensions/pulls").
          to_return(:status => 200, :body => %q({"html_url": "http://github.com/repo/project/pulls/1"}), :headers => {})

        # The Review Buddy should be @mentioned in the message
        Socialcast::Gitx::CLI.any_instance.should_receive(:post).with("#reviewrequest for FOO #scgitx\n\n/cc @SocialcastDevelopers\n\nAssigned to @VanMiranda\n\ntesting\n\n", :url => 'http://github.com/repo/project/pulls/1', :message_type => 'review_request')
        Socialcast::Gitx::CLI.start ['reviewrequest', '--description', 'testing']
      end
      it 'should create github pull request' do end # see expectations
      it 'should post socialcast message' do end # see expectations
      it 'should run expected commands' do
        Socialcast::Gitx::CLI.stubbed_executed_commands.should == [
          "git pull origin FOO",
          "git pull origin master",
          "git push origin HEAD"
        ]
      end
    end
  end

  describe '#promote' do
    before do
      Socialcast::Gitx::CLI.start ['promote']
    end
    it 'should integrate into staging' do
      Socialcast::Gitx::CLI.stubbed_executed_commands.should == [
        "git pull origin FOO",
        "git pull origin master",
        "git push origin HEAD",
        "git branch -D staging",
        "git fetch origin",
        "git checkout staging",
        "git pull . FOO",
        "git push origin HEAD",
        "git checkout FOO",
        "git branch -D prototype",
        "git fetch origin",
        "git checkout prototype",
        "git pull . staging",
        "git push origin HEAD",
        "git checkout staging",
        "git checkout FOO"
      ]
    end
  end
end
