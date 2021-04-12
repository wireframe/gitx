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
  let(:executor) { cli.send(:executor) }

  describe '#start' do
    context 'when user inputs branch that is valid' do
      before do
        expect(cli).to receive(:checkout_branch).with('main').ordered
        expect(executor).to receive(:execute).with('git', 'pull').ordered
        expect(repo).to receive(:create_branch).with('new-branch', 'main').ordered
        expect(cli).to receive(:checkout_branch).with('new-branch').ordered
        expect(executor).to receive(:execute).with('git', 'commit', '--allow-empty', '--message', '[gitx] Start work on new-branch').ordered

        cli.start 'new-branch'
      end
      it do
        should meet_expectations
      end
    end
    context 'when user inputs branch with slash' do
      before do
        expect(cli).to receive(:checkout_branch).with('main').ordered
        expect(executor).to receive(:execute).with('git', 'pull').ordered
        expect(repo).to receive(:create_branch).with('foo/ryan', 'main').ordered
        expect(cli).to receive(:checkout_branch).with('foo/ryan').ordered
        expect(executor).to receive(:execute).with('git', 'commit', '--allow-empty', '--message', '[gitx] Start work on foo/ryan').ordered

        cli.start 'foo/ryan'
      end
      it do
        should meet_expectations
      end
    end
    context 'when user does not input a branch name' do
      before do
        expect(cli).to receive(:ask).and_return('new-branch')

        expect(cli).to receive(:checkout_branch).with('main').ordered
        expect(executor).to receive(:execute).with('git', 'pull').ordered
        expect(repo).to receive(:create_branch).with('new-branch', 'main').ordered
        expect(cli).to receive(:checkout_branch).with('new-branch').ordered
        expect(executor).to receive(:execute).with('git', 'commit', '--allow-empty', '--message', '[gitx] Start work on new-branch').ordered

        cli.start
      end
      it 'prompts user to enter a new branch name' do
        should meet_expectations
      end
    end
    context 'when user inputs an invalid branch name' do
      before do
        expect(cli).to receive(:ask).and_return('new-branch')

        expect(cli).to receive(:checkout_branch).with('main').ordered
        expect(executor).to receive(:execute).with('git', 'pull').ordered
        expect(repo).to receive(:create_branch).with('new-branch', 'main').ordered
        expect(cli).to receive(:checkout_branch).with('new-branch').ordered
        expect(executor).to receive(:execute).with('git', 'commit', '--allow-empty', '--message', '[gitx] Start work on new-branch').ordered

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

        expect(cli).to receive(:checkout_branch).with('main').ordered
        expect(executor).to receive(:execute).with('git', 'pull').ordered
        expect(repo).to receive(:create_branch).with('new-branch', 'main').ordered
        expect(cli).to receive(:checkout_branch).with('new-branch').ordered
        expect(executor).to receive(:execute).with('git', 'commit', '--allow-empty', '--message', '[gitx] Start work on new-branch').ordered

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

        expect(cli).to receive(:checkout_branch).with('main').ordered
        expect(executor).to receive(:execute).with('git', 'pull').ordered
        expect(repo).to receive(:create_branch).with('new-branch', 'main').ordered
        expect(cli).to receive(:checkout_branch).with('new-branch').ordered
        expect(executor).to receive(:execute).with('git', 'commit', '--allow-empty', '--message', '[gitx] Start work on new-branch').ordered

        cli.start 'bar'
      end
      it 'prompts user to enter a new branch name' do
        should meet_expectations
      end
    end
    context 'when --issue option is used with a numeric issue ID' do
      let(:options) do
        {
          issue: '10'
        }
      end
      before do
        expect(cli).to receive(:checkout_branch).with('main').ordered
        expect(executor).to receive(:execute).with('git', 'pull').ordered
        expect(repo).to receive(:create_branch).with('new-branch', 'main').ordered
        expect(cli).to receive(:checkout_branch).with('new-branch').ordered
        expect(executor).to receive(:execute).with('git', 'commit', '--allow-empty', '--message', "[gitx] Start work on new-branch\n\nConnected to #10").ordered

        cli.start 'new-branch'
      end
      it 'creates empty commit with link to issue id' do
        should meet_expectations
      end
    end
    context 'when --issue option is used with a non-numeric issue ID' do
      let(:options) do
        {
          issue: 'FOO-123'
        }
      end
      before do
        expect(cli).to receive(:checkout_branch).with('main').ordered
        expect(executor).to receive(:execute).with('git', 'pull').ordered
        expect(repo).to receive(:create_branch).with('new-branch', 'main').ordered
        expect(cli).to receive(:checkout_branch).with('new-branch').ordered
        expect(executor).to receive(:execute).with('git', 'commit', '--allow-empty', '--message', "[gitx] Start work on new-branch\n\nConnected to FOO-123").ordered

        cli.start 'new-branch'
      end
      it 'creates empty commit with link to issue id' do
        should meet_expectations
      end
    end
  end
end
