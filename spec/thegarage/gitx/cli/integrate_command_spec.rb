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
  let(:branch) { double('fake branch', name: 'feature-branch') }

  before do
    allow(cli).to receive(:current_branch).and_return(branch)
  end

  describe '#integrate' do
    let(:fake_update_command) { double('fake update command') }
    before do
      allow(Thegarage::Gitx::Cli::UpdateCommand).to receive(:new).and_return(fake_update_command)
    end
    context 'when target branch is ommitted' do
      before do
        expect(fake_update_command).to receive(:update)

        expect(cli).to receive(:run_cmd).with("git branch -D staging", allow_failure: true).ordered
        expect(cli).to receive(:run_cmd).with("git fetch origin").ordered
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
    context 'when target branch == prototype' do
      before do
        expect(fake_update_command).to receive(:update)

        expect(cli).to receive(:run_cmd).with("git branch -D prototype", allow_failure: true).ordered
        expect(cli).to receive(:run_cmd).with("git fetch origin").ordered
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
    context 'when merge conflicts occur' do
      before do
        expect(fake_update_command).to receive(:update)

        # setup spies
        expect(cli).to receive(:run_cmd).with("git branch -D staging", allow_failure: true).ordered
        expect(cli).to receive(:run_cmd).with("git fetch origin").ordered
        expect(cli).to receive(:run_cmd).with("git checkout staging").ordered
        expect(cli).to receive(:run_cmd).with("git merge feature-branch").and_raise('git merge feature-branch failed').ordered


        # setup test
        expect { cli.integrate }.to raise_error(/Merge Conflict Occurred. Please fix merge conflict and rerun command with --resume feature-branch flag/)
      end
      it 'raises a helpful error' do
        should meet_expectations
      end
    end
    context 'with --resume "feature-branch" flag when feature-branch exists' do
      let(:options) do
        {
          resume: true,
          feature_branch: 'feature-branch'
        }
      end
      let(:repo) { cli.send(:repo) }
      let(:branches) { double(each_name: ['feature-branch']) }
      before do
        expect(repo).to receive(:branches).and_return(branches)

        expect(cli).not_to receive(:run_cmd).with("git branch -D staging")
        expect(cli).to receive(:run_cmd).with("git push origin HEAD").ordered
        expect(options[:feature_branch]).to match(/feature-branch/)
        expect(cli).to receive(:run_cmd).with("git checkout feature-branch")
        # binding.pry
        cli.integrate
      end
      it 'does not delete local staging branch' do
        should meet_expectations
      end
    end

    context 'with --resume "feature-branch" flag when feature-branch does not exist' do
      let(:options) do
        {
          resume: true,
          feature_branch: 'feature-branch'
        }
      end
      before do
        expect(cli).not_to receive(:run_cmd).with("git branch -D staging")
        expect(cli).to receive(:run_cmd).with("git push origin HEAD").ordered
        expect(options[:feature_branch]).to match(/feature-branch/)
        expect(cli).not_to receive(:run_cmd).with("git checkout feature-branch").and_raise('some error').ordered

        expect { cli.integrate }.to raise_error(/#{options[:feature_branch]} does not exist please make sure you typed the correct branch and run command again/)
      end
      it 'raises error' do
        should meet_expectations
      end
    end
  end
end
