require 'spec_helper'
require 'gitx/cli/integrate_command'

describe Gitx::Cli::IntegrateCommand do
  let(:args) { [] }
  let(:options) { {} }
  let(:config) do
    {
      pretend: true
    }
  end
  let(:cli) { described_class.new(args, options, config) }
  let(:executor) { cli.send(:executor) }
  let(:current_branch) { double('fake branch', name: 'feature-branch', head?: true) }
  let(:repo) { cli.send(:repo) }
  let(:remote_branch_names) { ['origin/staging', 'origin/prototype'] }
  let(:local_branch_names) { ['feature-branch'] }
  let(:authorization_token) { '123123' }

  before do
    allow(cli).to receive(:current_branch).and_return(current_branch)
    branches = double('fake branches')
    allow(branches).to receive(:each_name).with(:local).and_return(local_branch_names)
    allow(branches).to receive(:each_name).with(:remote).and_return(remote_branch_names)
    allow(repo).to receive(:branches).and_return(branches)
    allow(cli).to receive(:authorization_token).and_return(authorization_token)
  end

  describe '#integrate' do
    context 'when integration branch is ommitted and remote branch exists' do
      let(:remote_branch_names) { ['origin/staging'] }
      before do
        expect(executor).to receive(:execute).with('git', 'update').ordered
        expect(executor).to receive(:execute).with('git', 'fetch', 'origin').ordered
        expect(executor).to receive(:execute).with('git', 'branch', '--delete', '--force', 'staging').ordered
        expect(executor).to receive(:execute).with('git', 'checkout', 'staging').ordered
        expect(executor).to receive(:execute).with('git', 'merge', '--no-ff', '--message', "[gitx] Integrate feature-branch into staging\n\nConnected to #10", 'feature-branch').ordered
        expect(executor).to receive(:execute).with('git', 'push', 'origin', 'HEAD').ordered
        expect(executor).to receive(:execute).with('git', 'checkout', 'feature-branch').ordered

        VCR.use_cassette('pull_request_does_exist_with_success_status') do
          cli.integrate
        end
      end
      it 'defaults to staging branch' do
        should meet_expectations
      end
    end
    context 'when current_branch == master' do
      let(:current_branch) { double('fake branch', name: 'master', head?: true) }
      let(:local_branch_names) { ['master'] }
      let(:remote_branch_names) { ['origin/staging'] }
      before do
        expect(executor).to receive(:execute).with('git', 'update').ordered
        expect(executor).to receive(:execute).with('git', 'fetch', 'origin').ordered
        expect(executor).to receive(:execute).with('git', 'branch', '--delete', '--force', 'staging').ordered
        expect(executor).to receive(:execute).with('git', 'checkout', 'staging').ordered
        expect(executor).to receive(:execute).with('git', 'merge', '--no-ff', '--message', '[gitx] Integrate master into staging', 'master').ordered
        expect(executor).to receive(:execute).with('git', 'push', 'origin', 'HEAD').ordered
        expect(executor).to receive(:execute).with('git', 'checkout', 'master').ordered

        cli.integrate
      end
      it 'does not create pull request' do
        expect(WebMock).to_not have_requested(:post, 'https://api.github.com/repos/wireframe/gitx/pulls')
      end
    end
    context 'when a pull request doesnt exist for the feature-branch' do
      let(:changelog) { '* made some fixes' }
      let(:new_pull_request) do
        {
          html_url: 'https://path/to/html/pull/request',
          issue_url: 'https://api/path/to/issue/url',
          number: 10,
          head: {
            ref: 'branch_name'
          }
        }
      end
      let(:changelog) { '2013-01-01 did some stuff' }
      before do
        allow(cli).to receive(:ask_editor).and_return('description')

        expect(executor).to receive(:execute).with('git', 'update').ordered
        expect(executor).to receive(:execute).with('git', 'checkout', 'feature-branch').ordered
        expect(executor).to receive(:execute).with('git', 'update').ordered
        expect(executor).to receive(:execute).with('git', 'log', 'origin/master...feature-branch', '--reverse', '--no-merges', '--pretty=format:* %B').and_return(changelog).ordered
        expect(executor).to receive(:execute).with('git', 'fetch', 'origin').ordered
        expect(executor).to receive(:execute).with('git', 'branch', '--delete', '--force', 'staging').ordered
        expect(executor).to receive(:execute).with('git', 'checkout', 'staging').ordered
        expect(executor).to receive(:execute).with('git', 'merge', '--no-ff', '--message', "[gitx] Integrate feature-branch into staging\n\nConnected to #10", 'feature-branch').ordered
        expect(executor).to receive(:execute).with('git', 'push', 'origin', 'HEAD').ordered
        expect(executor).to receive(:execute).with('git', 'checkout', 'feature-branch').ordered

        stub_request(:post, 'https://api.github.com/repos/wireframe/gitx/pulls').to_return(status: 201, body: new_pull_request.to_json, headers: { 'Content-Type' => 'application/json' })

        VCR.use_cassette('pull_request_does_not_exist') do
          cli.integrate
        end
      end
      it 'creates github pull request' do
        should meet_expectations
      end
      it 'runs expected commands' do
        should meet_expectations
      end
    end
    context 'when staging branch does not exist remotely' do
      let(:remote_branch_names) { [] }
      before do
        expect(repo).to receive(:create_branch).with('staging', 'master')

        expect(executor).to receive(:execute).with('git', 'update').ordered
        expect(executor).to receive(:execute).with('git', 'push', 'origin', 'staging:staging').ordered
        expect(executor).to receive(:execute).with('git', 'fetch', 'origin').ordered
        expect(executor).to receive(:execute).with('git', 'branch', '--delete', '--force', 'staging').and_raise(Gitx::Executor::ExecutionError).ordered
        expect(executor).to receive(:execute).with('git', 'checkout', 'staging').ordered
        expect(executor).to receive(:execute).with('git', 'merge', '--no-ff', '--message', "[gitx] Integrate feature-branch into staging\n\nConnected to #10", 'feature-branch').ordered
        expect(executor).to receive(:execute).with('git', 'push', 'origin', 'HEAD').ordered
        expect(executor).to receive(:execute).with('git', 'checkout', 'feature-branch').ordered

        VCR.use_cassette('pull_request_does_exist_with_success_status') do
          cli.integrate
        end
      end
      it 'creates remote aggregate branch' do
        should meet_expectations
      end
    end
    context 'when integration branch == prototype and remote branch exists' do
      let(:remote_branch_names) { ['origin/prototype'] }
      before do
        expect(executor).to receive(:execute).with('git', 'update').ordered
        expect(executor).to receive(:execute).with('git', 'fetch', 'origin').ordered
        expect(executor).to receive(:execute).with('git', 'branch', '--delete', '--force', 'prototype').ordered
        expect(executor).to receive(:execute).with('git', 'checkout', 'prototype').ordered
        expect(executor).to receive(:execute).with('git', 'merge', '--no-ff', '--message', "[gitx] Integrate feature-branch into prototype\n\nConnected to #10", 'feature-branch').ordered
        expect(executor).to receive(:execute).with('git', 'push', 'origin', 'HEAD').ordered
        expect(executor).to receive(:execute).with('git', 'checkout', 'feature-branch').ordered

        VCR.use_cassette('pull_request_does_exist_with_success_status') do
          cli.integrate 'prototype'
        end
      end
      it 'runs expected commands' do
        should meet_expectations
      end
    end
    context 'when integration branch is not an aggregate branch' do
      it 'raises an error' do
        expect { cli.integrate('some-other-branch') }.to raise_error(/Invalid aggregate branch: some-other-branch must be one of supported aggregate branches/)
      end
    end
    context 'when merge conflicts occur with the integrate command' do
      let(:remote_branch_names) { ['origin/staging'] }
      before do
        expect(executor).to receive(:execute).with('git', 'update').ordered
        expect(executor).to receive(:execute).with('git', 'fetch', 'origin').ordered
        expect(executor).to receive(:execute).with('git', 'branch', '--delete', '--force', 'staging').ordered
        expect(executor).to receive(:execute).with('git', 'checkout', 'staging').ordered
        expect(executor).to receive(:execute).with('git', 'merge', '--no-ff', '--message', "[gitx] Integrate feature-branch into staging\n\nConnected to #10", 'feature-branch')
                                             .and_raise('git merge feature-branch failed').ordered

        VCR.use_cassette('pull_request_does_exist_with_success_status') do
          expect { cli.integrate }.to raise_error(/Merge conflict occurred.  Please fix merge conflict and rerun command with --resume feature-branch flag/)
        end
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
      before do
        expect(executor).to receive(:execute).with('git', 'update').ordered
        expect(executor).not_to receive(:execute).with('git', 'branch', '--delete', '--force', 'staging')
        expect(executor).not_to receive(:execute).with('git', 'push', 'origin', 'HEAD')
        expect(executor).to receive(:execute).with('git', 'checkout', 'feature-branch')

        VCR.use_cassette('pull_request_does_exist_with_success_status') do
          cli.integrate
        end
      end
      it 'does not delete local staging branch' do
        should meet_expectations
      end
    end
    context 'with --resume "feature-branch" flag when feature-branch does not exist' do
      let(:options) do
        {
          resume: 'invalid-feature-branch'
        }
      end
      let(:local_branch_names) { ['feature-branch'] }
      before do
        expect(executor).to receive(:execute).with('git', 'update').ordered
        expect(cli).to receive(:ask).and_return('feature-branch')

        expect(executor).not_to receive(:execute).with('git', 'branch', '--delete', '--force', 'staging')
        expect(executor).not_to receive(:execute).with('git', 'push', 'origin', 'HEAD')
        expect(executor).to receive(:execute).with('git', 'checkout', 'feature-branch').ordered

        VCR.use_cassette('pull_request_does_exist_with_success_status') do
          cli.integrate
        end
      end
      it 'asks user for feature-branch name' do
        should meet_expectations
      end
    end
  end
end
