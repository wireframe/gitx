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
  let(:repo) { cli.send(:repo) }
  let(:branch) { double('fake branch', name: 'feature-branch') }

  before do
    allow(cli).to receive(:current_branch).and_return(branch)
  end

  describe '#integrate' do
    let(:fake_update_command) { double('fake update command') }
    let(:remote_branches) { double(each_name: ['origin/staging'] )}
    before do
      allow(Thegarage::Gitx::Cli::UpdateCommand).to receive(:new).and_return(fake_update_command)
    end
    context 'when target branch is ommitted' do
      before do
        expect(fake_update_command).to receive(:update)

        expect(repo).to receive(:branches).and_return(remote_branches)

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
      let(:remote_branches) { double(each_name: [] )}
      before do
        expect(fake_update_command).to receive(:update)

        expect(repo).to receive(:branches).and_return(remote_branches)
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
    context 'when target branch == prototype' do
      let(:remote_branches) { double(each_name: ['origin/prototype'] )}
      before do
        expect(fake_update_command).to receive(:update)

        expect(repo).to receive(:branches).and_return(remote_branches)

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
    context 'when target branch != staging || prototype' do
      it 'raises an error' do
        expect { cli.integrate('some-other-branch') }.to raise_error(/Only aggregate branches are allowed for integration/)
      end
    end
  end
end
