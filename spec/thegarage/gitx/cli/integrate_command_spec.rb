require 'spec_helper'
require 'thegarage/gitx/cli/integrate_command'

describe Thegarage::Gitx::Cli::IntegrateCommand do
  let(:args) { [] }
  let(:options) { {} }
  let(:config) do
    {
      pretend: true
    }
  end
  let(:cli) { Thegarage::Gitx::Cli::IntegrateCommand.new(args, options, config) }
  let(:current_branch) { double('fake branch', name: 'feature-branch', head?: true) }
  let(:repo) { cli.send(:repo) }
  let(:remote_branch_names) { ['origin/staging', 'origin/prototype'] }
  let(:local_branch_names) { ['feature-branch'] }

  before do
    allow(cli).to receive(:current_branch).and_return(current_branch)
    branches = double('fake branches')
    allow(branches).to receive(:each_name).with(:local).and_return(local_branch_names)
    allow(branches).to receive(:each_name).with(:remote).and_return(remote_branch_names)
    allow(repo).to receive(:branches).and_return(branches)
  end

  describe '#integrate' do
    context 'when integration branch is ommitted and remote branch exists' do
      let(:authorization_token) { '123123' }
      let(:remote_branch_names) { ['origin/staging'] }
      before do
        allow(cli).to receive(:authorization_token).and_return(authorization_token)
        expect(cli).to receive(:execute_command).with(Thegarage::Gitx::Cli::UpdateCommand, :update)

        expect(cli).to receive(:run_cmd).with("git fetch origin").ordered
        expect(cli).to receive(:run_cmd).with("git branch -D staging", allow_failure: true).ordered
        expect(cli).to receive(:run_cmd).with("git checkout staging").ordered
        expect(cli).to receive(:run_cmd).with("git merge feature-branch").ordered
        expect(cli).to receive(:run_cmd).with("git push origin HEAD").ordered
        expect(cli).to receive(:run_cmd).with("git checkout feature-branch").ordered

        stub_request(:post, /.*api.github.com.*/).to_return(:status => 201)

        VCR.use_cassette('pull_request_does_exist_with_success_status') do
          cli.integrate
        end
      end
      it 'defaults to staging branch' do
        should meet_expectations
      end
      it 'posts comment to pull request' do
        expect(WebMock).to have_requested(:post, "https://api.github.com/repos/thegarage/thegarage-gitx/issues/10/comments").
          with(body: {body: '[gitx] integrated into staging :twisted_rightwards_arrows:'})
      end
    end
    context 'when current_branch == master' do
      let(:current_branch) { double('fake branch', name: 'master', head?: true) }
      let(:local_branch_names) { ['master'] }
      let(:authorization_token) { '123123' }
      let(:remote_branch_names) { ['origin/staging'] }
      before do
        allow(cli).to receive(:authorization_token).and_return(authorization_token)
        expect(cli).to receive(:execute_command).with(Thegarage::Gitx::Cli::UpdateCommand, :update)

        expect(cli).to receive(:run_cmd).with("git fetch origin").ordered
        expect(cli).to receive(:run_cmd).with("git branch -D staging", allow_failure: true).ordered
        expect(cli).to receive(:run_cmd).with("git checkout staging").ordered
        expect(cli).to receive(:run_cmd).with("git merge master").ordered
        expect(cli).to receive(:run_cmd).with("git push origin HEAD").ordered
        expect(cli).to receive(:run_cmd).with("git checkout master").ordered

        cli.integrate
      end
      it 'does not create pull request' do
        expect(WebMock).to_not have_requested(:post, "https://api.github.com/repos/thegarage/thegarage-gitx/pulls")
      end
    end
    context 'when a pull request doesnt exist for the feature-branch' do
      let(:authorization_token) { '123123' }
      let(:changelog) { '* made some fixes' }
      let(:new_pull_request) do
        {
          html_url: "https://path/to/html/pull/request",
          issue_url: "https://api/path/to/issue/url",
          number: 10,
          head: {
            ref: "branch_name"
          }
        }
      end
      before do
        allow(cli).to receive(:ask_editor).and_return('description')
        allow(cli).to receive(:authorization_token).and_return(authorization_token)
        expect(cli).to receive(:execute_command).with(Thegarage::Gitx::Cli::UpdateCommand, :update).twice

        expect(cli).to receive(:run_cmd).with("git fetch origin").ordered
        expect(cli).to receive(:run_cmd).with("git branch -D staging", allow_failure: true).ordered
        expect(cli).to receive(:run_cmd).with("git checkout staging").ordered
        expect(cli).to receive(:run_cmd).with("git merge feature-branch").ordered
        expect(cli).to receive(:run_cmd).with("git push origin HEAD").ordered
        expect(cli).to receive(:run_cmd).with("git checkout feature-branch").ordered
        expect(cli).to receive(:run_cmd).with('git checkout feature-branch').ordered
        expect(cli).to receive(:run_cmd).with("git log master...feature-branch --reverse --no-merges --pretty=format:'* %s%n%b'").and_return("2013-01-01 did some stuff").ordered

        stub_request(:post, 'https://api.github.com/repos/thegarage/thegarage-gitx/pulls').to_return(:status => 201, :body => new_pull_request.to_json, :headers => {'Content-Type' => 'application/json'})
        stub_request(:post, 'https://api.github.com/repos/thegarage/thegarage-gitx/issues/10/comments').to_return(:status => 201)

        VCR.use_cassette('pull_request_does_not_exist') do
          cli.integrate
        end
      end
      it 'creates github pull request' do
        should meet_expectations
      end
      it 'creates github comment for integration' do
        expect(WebMock).to have_requested(:post, "https://api.github.com/repos/thegarage/thegarage-gitx/issues/10/comments").
          with(body: {body: '[gitx] integrated into staging :twisted_rightwards_arrows:'})
      end
      it 'runs expected commands' do
        should meet_expectations
      end
    end
    context 'when staging branch does not exist remotely' do
      let(:authorization_token) { '123123' }
      let(:remote_branch_names) { [] }
      before do
        allow(cli).to receive(:authorization_token).and_return(authorization_token)
        expect(cli).to receive(:execute_command).with(Thegarage::Gitx::Cli::UpdateCommand, :update)

        expect(repo).to receive(:create_branch).with('staging', 'master')

        expect(cli).to receive(:run_cmd).with('git push origin staging:staging').ordered

        expect(cli).to receive(:run_cmd).with("git fetch origin").ordered
        expect(cli).to receive(:run_cmd).with("git branch -D staging", allow_failure: true).ordered
        expect(cli).to receive(:run_cmd).with("git checkout staging").ordered
        expect(cli).to receive(:run_cmd).with("git merge feature-branch").ordered
        expect(cli).to receive(:run_cmd).with("git push origin HEAD").ordered
        expect(cli).to receive(:run_cmd).with("git checkout feature-branch").ordered

        stub_request(:post, /.*api.github.com.*/).to_return(:status => 201)

        VCR.use_cassette('pull_request_does_exist_with_success_status') do
          cli.integrate
        end
      end
      it 'creates remote aggregate branch' do
        should meet_expectations
      end
      it 'posts comment to pull request' do
        expect(WebMock).to have_requested(:post, "https://api.github.com/repos/thegarage/thegarage-gitx/issues/10/comments")
      end
    end
    context 'when integration branch == prototype and remote branch exists' do
      let(:authorization_token) { '123123' }
      let(:remote_branch_names) { ['origin/prototype'] }
      before do
        allow(cli).to receive(:authorization_token).and_return(authorization_token)
        expect(cli).to receive(:execute_command).with(Thegarage::Gitx::Cli::UpdateCommand, :update)

        expect(cli).to receive(:run_cmd).with("git fetch origin").ordered
        expect(cli).to receive(:run_cmd).with("git branch -D prototype", allow_failure: true).ordered
        expect(cli).to receive(:run_cmd).with("git checkout prototype").ordered
        expect(cli).to receive(:run_cmd).with("git merge feature-branch").ordered
        expect(cli).to receive(:run_cmd).with("git push origin HEAD").ordered
        expect(cli).to receive(:run_cmd).with("git checkout feature-branch").ordered

        stub_request(:post, /.*api.github.com.*/).to_return(:status => 201)

        VCR.use_cassette('pull_request_does_exist_with_success_status') do
          cli.integrate 'prototype'
        end
      end
      it 'runs expected commands' do
        should meet_expectations
      end
      it 'posts comment to pull request' do
        expect(WebMock).to have_requested(:post, "https://api.github.com/repos/thegarage/thegarage-gitx/issues/10/comments")
      end
    end
    context 'when integration branch is not an aggregate branch' do
      it 'raises an error' do
        expect { cli.integrate('some-other-branch') }.to raise_error(/Invalid aggregate branch: some-other-branch must be one of supported aggregate branches/)
      end
    end
    context 'when merge conflicts occur during the Thegarage::Gitx::Cli::updatecommand execution' do
      let(:remote_branch_names) { ['origin/staging'] }
      before do
        expect(cli).to receive(:execute_command).with(Thegarage::Gitx::Cli::UpdateCommand, :update).and_raise(Thegarage::Gitx::Cli::BaseCommand::MergeError)

        expect { cli.integrate }.to raise_error(Thegarage::Gitx::Cli::BaseCommand::MergeError, 'Merge Conflict Occurred. Please Merge Conflict Occurred. Please fix merge conflict and rerun the integrate command')
      end
      it 'raises a helpful error' do
        should meet_expectations
      end
    end
    context 'when merge conflicts occur with the integrate command' do
      let(:remote_branch_names) { ['origin/staging'] }
      before do
        expect(cli).to receive(:execute_command).with(Thegarage::Gitx::Cli::UpdateCommand, :update)

        expect(cli).to receive(:run_cmd).with("git fetch origin").ordered
        expect(cli).to receive(:run_cmd).with("git branch -D staging", allow_failure: true).ordered
        expect(cli).to receive(:run_cmd).with("git checkout staging").ordered
        expect(cli).to receive(:run_cmd).with("git merge feature-branch").and_raise('git merge feature-branch failed').ordered

        expect { cli.integrate }.to raise_error(/Merge Conflict Occurred. Please fix merge conflict and rerun command with --resume feature-branch flag/)
      end
      it 'raises a helpful error' do
        should meet_expectations
      end
    end
    context 'with --resume "feature-branch" flag when feature-branch exists' do
      let(:options) do
        {
          resume: 'feature-branch'
        }
      end
      let(:repo) { cli.send(:repo) }
      let(:authorization_token) { '123123' }
      before do
        allow(cli).to receive(:authorization_token).and_return(authorization_token)

        expect(cli).to receive(:execute_command).with(Thegarage::Gitx::Cli::UpdateCommand, :update)

        expect(cli).not_to receive(:run_cmd).with("git branch -D staging")
        expect(cli).not_to receive(:run_cmd).with("git push origin HEAD")
        expect(cli).to receive(:run_cmd).with("git checkout feature-branch")

        stub_request(:post, /.*api.github.com.*/).to_return(:status => 201)

        VCR.use_cassette('pull_request_does_exist_with_success_status') do
          cli.integrate
        end
      end
      it 'does not delete local staging branch' do
        should meet_expectations
      end
      it 'posts comment to pull request' do
        expect(WebMock).to have_requested(:post, "https://api.github.com/repos/thegarage/thegarage-gitx/issues/10/comments")
      end
    end
    context 'with --resume "feature-branch" flag when feature-branch does not exist' do
      let(:options) do
        {
          resume: 'invalid-feature-branch'
        }
      end
      let(:local_branch_names) { ['feature-branch'] }
      let(:authorization_token) { '123123' }
      before do
        allow(cli).to receive(:authorization_token).and_return(authorization_token)
        expect(cli).to receive(:execute_command).with(Thegarage::Gitx::Cli::UpdateCommand, :update)
        expect(cli).to receive(:ask).and_return('feature-branch')

        expect(cli).not_to receive(:run_cmd).with("git branch -D staging")
        expect(cli).not_to receive(:run_cmd).with("git push origin HEAD")
        expect(cli).to receive(:run_cmd).with("git checkout feature-branch").ordered

        stub_request(:post, /.*api.github.com.*/).to_return(:status => 201)
        VCR.use_cassette('pull_request_does_exist_with_success_status') do
          cli.integrate
        end
      end
      it 'asks user for feature-branch name' do
        should meet_expectations
      end
      it 'posts comment to pull request' do
        expect(WebMock).to have_requested(:post, "https://api.github.com/repos/thegarage/thegarage-gitx/issues/10/comments")
      end
    end
  end
end
