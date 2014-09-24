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
    let(:fake_update_command) { double('fake update command') }
    before do
      allow(Thegarage::Gitx::Cli::UpdateCommand).to receive(:new).and_return(fake_update_command)
    end
    context 'when integration branch is ommitted and remote branch exists' do
      let(:remote_branch_names) { ['origin/staging'] }
      before do
        expect(fake_update_command).to receive(:update)

        expect(cli).to receive(:run_cmd).with("git fetch origin").ordered
        expect(cli).to receive(:run_cmd).with("git branch -D staging", allow_failure: true).ordered
        expect(cli).to receive(:run_cmd).with("git checkout staging").ordered
        expect(cli).to receive(:run_cmd).with("git merge feature-branch").ordered
        expect(cli).to receive(:run_cmd).with("git push origin HEAD").ordered
        expect(cli).to receive(:run_cmd).with("git checkout feature-branch").ordered

        cli.integrate
      end
      it 'defaults to staging branch' do
        should meet_expectations
      end
    end
    context 'when staging branch does not exist remotely' do
      let(:remote_branch_names) { [] }
      before do
        expect(fake_update_command).to receive(:update)

        expect(repo).to receive(:create_branch).with('staging', 'master')

        expect(cli).to receive(:run_cmd).with('git push origin staging:staging').ordered

        expect(cli).to receive(:run_cmd).with("git fetch origin").ordered
        expect(cli).to receive(:run_cmd).with("git branch -D staging", allow_failure: true).ordered
        expect(cli).to receive(:run_cmd).with("git checkout staging").ordered
        expect(cli).to receive(:run_cmd).with("git merge feature-branch").ordered
        expect(cli).to receive(:run_cmd).with("git push origin HEAD").ordered
        expect(cli).to receive(:run_cmd).with("git checkout feature-branch").ordered

        cli.integrate
      end
      it 'creates remote aggregate branch' do
        should meet_expectations
      end
    end
    context 'when integration branch == prototype and remote branch exists' do
      let(:remote_branch_names) { ['origin/prototype'] }
      before do
        expect(fake_update_command).to receive(:update)

        expect(cli).to receive(:run_cmd).with("git fetch origin").ordered
        expect(cli).to receive(:run_cmd).with("git branch -D prototype", allow_failure: true).ordered
        expect(cli).to receive(:run_cmd).with("git checkout prototype").ordered
        expect(cli).to receive(:run_cmd).with("git merge feature-branch").ordered
        expect(cli).to receive(:run_cmd).with("git push origin HEAD").ordered
        expect(cli).to receive(:run_cmd).with("git checkout feature-branch").ordered

        cli.integrate 'prototype'
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
    context 'when merge conflicts occur during the updatecommand execution' do
      let(:remote_branch_names) { ['origin/staging'] }
      before do
        expect(fake_update_command).to receive(:update).and_raise(Thegarage::Gitx::Cli::BaseCommand::MergeError)

        expect { cli.integrate }.to raise_error(Thegarage::Gitx::Cli::BaseCommand::MergeError, 'Merge Conflict Occurred. Please Merge Conflict Occurred. Please fix merge conflict and rerun the integrate command')
      end
      it 'raises a helpful error' do
        should meet_expectations
      end
    end
    context 'when merge conflicts occur with the integrate command' do
      let(:remote_branch_names) { ['origin/staging'] }
      before do
        expect(fake_update_command).to receive(:update)

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
      before do
        expect(fake_update_command).to receive(:update)

        expect(cli).not_to receive(:run_cmd).with("git branch -D staging")
        expect(cli).not_to receive(:run_cmd).with("git push origin HEAD")
        expect(cli).to receive(:run_cmd).with("git checkout feature-branch")

        cli.integrate
      end
      it 'does not delete local staging branch' do
        should meet_expectations
      end
    end
    context 'with --resume "feature-branch" flag when feature-branch does not exist' do
      let(:options) do
        {
          resume: 'feature-branch'
        }
      end
      let(:repo) { cli.send(:repo) }
      let(:branches) { double(each_name: ['my-feature-branch'])}
      let(:local_branch_names) { ['another-feature-branch'] }
      before do
        expect(fake_update_command).to receive(:update)
        expect(cli).to receive(:ask).and_return('another-feature-branch')

        expect(cli).not_to receive(:run_cmd).with("git branch -D staging")
        expect(cli).not_to receive(:run_cmd).with("git push origin HEAD")
        expect(cli).to receive(:run_cmd).with("git checkout another-feature-branch").ordered

        cli.integrate
      end
      it 'asks user for feature-branch name' do
        should meet_expectations
      end
    end
  end
end
