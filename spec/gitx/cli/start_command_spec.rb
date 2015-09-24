require 'spec_helper'
require 'gitx/cli/start_command'

describe Gitx::Cli::StartCommand do
  let(:args) { [] }
  let(:options) { {} }
  let(:config) do
    {
      pretend: true
    }
  end
  let(:cli) { described_class.new(args, options, config) }
  let(:repo) { cli.send(:repo) }
  let(:exit_value) { double(:exit_value, success?: true) }
  let(:thread) { double(:thread, value: exit_value) }
  let(:stdoutput) { StringIO.new('') }

  describe '#start' do
    context 'when user inputs branch that is valid' do
      before do
        expect(cli).to receive(:checkout_branch).with('master').ordered
        expect(Open3).to receive(:popen2e).with('git', 'pull').and_yield(nil, stdoutput, thread).ordered
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
        expect(Open3).to receive(:popen2e).with('git', 'pull').and_yield(nil, stdoutput, thread).ordered
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
        expect(Open3).to receive(:popen2e).with('git', 'pull').and_yield(nil, stdoutput, thread).ordered
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
        expect(Open3).to receive(:popen2e).with('git', 'pull').and_yield(nil, stdoutput, thread).ordered
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
        expect(Open3).to receive(:popen2e).with('git', 'pull').and_yield(nil, stdoutput, thread).ordered
        expect(repo).to receive(:create_branch).with('new-branch', 'master').ordered
        expect(cli).to receive(:checkout_branch).with('new-branch').ordered

        cli.start 'bar'
      end
      it 'prompts user to enter a new branch name' do
        should meet_expectations
      end
    end
    context 'when --issue option is used' do
      let(:options) do
        {
          issue: 10
        }
      end
      before do
        expect(cli).to receive(:checkout_branch).with('master').ordered
        expect(Open3).to receive(:popen2e).with('git', 'pull').and_yield(nil, stdoutput, thread).ordered
        expect(repo).to receive(:create_branch).with('new-branch', 'master').ordered
        expect(cli).to receive(:checkout_branch).with('new-branch').ordered
        expect(Open3).to receive(:popen2e).with('git', 'commit', '--allow-empty', '--message', 'Starting work on new-branch (Issue #10)').and_yield(nil, stdoutput, thread).ordered

        cli.start 'new-branch'
      end
      it 'creates empty commit with link to issue id' do
        should meet_expectations
      end
    end
  end
end
