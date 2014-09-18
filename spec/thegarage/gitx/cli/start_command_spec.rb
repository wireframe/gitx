require 'spec_helper'
require 'thegarage/gitx/cli/start_command'

describe Thegarage::Gitx::Cli::StartCommand do
  let(:args) { [] }
  let(:options) { {} }
  let(:config) do
    {
      pretend: true
    }
  end
  let(:cli) { Thegarage::Gitx::Cli::StartCommand.new(args, options, config) }
  let(:repo) { cli.send(:repo) }

  describe '#start' do
    context 'when user inputs branch that is valid' do
      before do
        expect(cli).to receive(:checkout_branch).with('master').ordered
        expect(cli).to receive(:run_cmd).with('git pull').ordered
        expect(repo).to receive(:create_branch).with('new-branch', 'master').ordered
        expect(cli).to receive(:checkout_branch).with('new-branch').ordered

        cli.start 'new-branch'
      end
      it do
        should meet_expectations
      end
    end
    context 'when user does not input a branch name' do
      before do
        expect(cli).to receive(:ask).and_return('new-branch')

        expect(cli).to receive(:checkout_branch).with('master').ordered
        expect(cli).to receive(:run_cmd).with('git pull').ordered
        expect(repo).to receive(:create_branch).with('new-branch', 'master').ordered
        expect(cli).to receive(:checkout_branch).with('new-branch').ordered

        cli.start
      end
      it 'prompts user to enter a new branch name' do
        should meet_expectations
      end
    end
    context 'when user inputs an invalid branch name' do
      before do
        expect(cli).to receive(:ask).and_return('new-branch')

        expect(cli).to receive(:checkout_branch).with('master').ordered
        expect(cli).to receive(:run_cmd).with('git pull').ordered
        expect(repo).to receive(:create_branch).with('new-branch', 'master').ordered
        expect(cli).to receive(:checkout_branch).with('new-branch').ordered

        cli.start 'a bad_branch-name?'
      end
      it 'prompts user to enter a new branch name' do
        should meet_expectations
      end
    end
    context 'when branch already exists in local repo' do
      let(:branches) { double(each_name: ['bar']) }
      before do
        expect(repo).to receive(:branches).and_return(branches)

        expect(cli).to receive(:ask).and_return('new-branch')

        expect(cli).to receive(:checkout_branch).with('master').ordered
        expect(cli).to receive(:run_cmd).with('git pull').ordered
        expect(repo).to receive(:create_branch).with('new-branch', 'master').ordered
        expect(cli).to receive(:checkout_branch).with('new-branch').ordered

        cli.start 'bar'
      end
      it 'prompts user to enter a new branch name' do
        should meet_expectations
      end
    end
    context 'when branch already exists in remote repo' do
      let(:branches) { double(each_name: ['origin/bar']) }
      before do
        expect(repo).to receive(:branches).and_return(branches)

        expect(cli).to receive(:ask).and_return('new-branch')

        expect(cli).to receive(:checkout_branch).with('master').ordered
        expect(cli).to receive(:run_cmd).with('git pull').ordered
        expect(repo).to receive(:create_branch).with('new-branch', 'master').ordered
        expect(cli).to receive(:checkout_branch).with('new-branch').ordered

        cli.start 'bar'
      end
      it 'prompts user to enter a new branch name' do
        should meet_expectations
      end
    end
  end
end
