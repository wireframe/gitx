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
  let(:remote_branch_names) { [] }

  before do
    allow(cli).to receive(:current_branch).and_return(current_branch)
    allow(repo).to receive(:branches).and_return(double(each_name: remote_branch_names))
  end

  describe '#integrate' do
    let(:fake_update_command) { double('fake update command') }
    before do
      allow(Thegarage::Gitx::Cli::UpdateCommand).to receive(:new).and_return(fake_update_command)
    end
    context 'when target branch is ommitted and remote branch exists' do
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
    context 'when target branch == prototype and remote branch exists' do
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
    context 'when target branch is not an aggregate branch' do
      it 'raises an error' do
        expect { cli.integrate('some-other-branch') }.to raise_error(/Invalid aggregate branch: some-other-branch must be one of supported aggregate branches/)
      end
    end
  end
end
