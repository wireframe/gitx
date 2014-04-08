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
  let(:branch) { double('fake branch', name: 'feature-branch') }

  before do
    allow(cli).to receive(:current_branch).and_return(branch)
  end

  describe '#start' do
    context 'when user inputs branch that is valid' do
      before do
        expect(cli).to receive(:run_cmd).with('git checkout master').ordered
        expect(cli).to receive(:run_cmd).with('git pull').ordered
        expect(cli).to receive(:run_cmd).with('git checkout -b new-branch').ordered

        cli.start 'new-branch'
      end
      it do
        should meet_expectations
      end
    end
    context 'when user does not input a branch name' do
      before do
        expect(cli).to receive(:ask).and_return('another-new-branch')

        expect(cli).to receive(:run_cmd).with('git checkout master').ordered
        expect(cli).to receive(:run_cmd).with('git pull').ordered
        expect(cli).to receive(:run_cmd).with('git checkout -b another-new-branch').ordered

        cli.start
      end
      it 'prompts user to enter a new branch name' do
        should meet_expectations
      end
    end
    context 'when user inputs an invalid branch name' do
      before do
        expect(cli).to receive(:ask).and_return('another-new-branch')

        expect(cli).to receive(:run_cmd).with('git checkout master').ordered
        expect(cli).to receive(:run_cmd).with('git pull').ordered
        expect(cli).to receive(:run_cmd).with('git checkout -b another-new-branch').ordered

        cli.start 'a bad_branch-name?'
      end
      it 'prompts user to enter a new branch name' do
        should meet_expectations
      end
    end
  end
end
