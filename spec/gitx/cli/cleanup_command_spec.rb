require 'spec_helper'
require 'gitx/cli/cleanup_command'

describe Gitx::Cli::CleanupCommand do
  let(:args) { [] }
  let(:options) { {} }
  let(:config) do
    {
      pretend: true
    }
  end
  let(:cli) { described_class.new(args, options, config) }
  let(:executor) { cli.send(:executor) }
  let(:remote_branches) { [] }
  let(:local_branches) { [] }
  let(:workdir) { '.' }
  let(:oid) { '123123' }
  let(:target) { double(:target, oid: oid) }
  let(:reference) { double(:ref, target: target) }
  let(:repo) { double(:repo, workdir: workdir, head: reference) }
  let(:branches) { double(:branches) }

  before do
    allow(cli).to receive(:repo).and_return(repo)
    allow(repo).to receive(:branches).and_return(branches)
    allow(repo).to receive(:merge_base).with(target, target).and_return(oid)
    allow(branches).to receive(:each).with(:local).and_return(local_branches)
    allow(branches).to receive(:each).with(:remote).and_return(remote_branches)
  end

  describe '#cleanup' do
    context 'when merged local branches exist' do
      let(:local_branches) do
        [
          double(:branch, name: 'merged-local-feature', resolve: reference)
        ]
      end
      before do
        allow(cli).to receive(:say)

        expect(executor).to receive(:execute).with('git', 'checkout', 'main').ordered
        expect(executor).to receive(:execute).with('git', 'pull').ordered
        expect(executor).to receive(:execute).with('git', 'remote', 'prune', 'origin').ordered
        expect(executor).to receive(:execute).with('git', 'branch', '--delete', 'merged-local-feature').ordered

        cli.cleanup
      end
      it 'runs expected commands' do
        should meet_expectations
      end
    end
    context 'when merged remote branches exist' do
      let(:remote_branches) do
        [
          double(:branch, name: 'origin/merged-remote-feature', resolve: reference)
        ]
      end
      before do
        allow(cli).to receive(:say)

        expect(executor).to receive(:execute).with('git', 'checkout', 'main').ordered
        expect(executor).to receive(:execute).with('git', 'pull').ordered
        expect(executor).to receive(:execute).with('git', 'remote', 'prune', 'origin').ordered
        expect(executor).to receive(:execute).with('git', 'push', 'origin', '--delete', 'merged-remote-feature').ordered

        cli.cleanup
      end
      it 'runs expected commands' do
        should meet_expectations
      end
    end
    context 'when merged remote branches with slash exist' do
      let(:remote_branches) do
        [
          double(:branch, name: 'origin/merged-remote-feature/review', resolve: reference)
        ]
      end
      before do
        allow(cli).to receive(:say)

        expect(executor).to receive(:execute).with('git', 'checkout', 'main').ordered
        expect(executor).to receive(:execute).with('git', 'pull').ordered
        expect(executor).to receive(:execute).with('git', 'remote', 'prune', 'origin').ordered
        expect(executor).to receive(:execute).with('git', 'push', 'origin', '--delete', 'merged-remote-feature/review').ordered

        cli.cleanup
      end
      it 'runs expected commands' do
        should meet_expectations
      end
    end
    context 'when merged branch includes the base_branch' do
      let(:base_branch) { 'custom-base-branch' }
      let(:remote_branches) do
        [
          double(:branch, name: "origin/#{base_branch}", resolve: reference)
        ]
      end
      before do
        configuration = cli.send(:config)
        configuration.config[:base_branch] = base_branch
        allow(cli).to receive(:say)

        expect(executor).to receive(:execute).with('git', 'checkout', base_branch).ordered
        expect(executor).to receive(:execute).with('git', 'pull').ordered
        expect(executor).to receive(:execute).with('git', 'remote', 'prune', 'origin').ordered
        expect(executor).to_not receive(:execute).with('git', 'push', 'origin', '--delete', base_branch)

        cli.cleanup
      end
      it 'does not delete remote branch' do
        should meet_expectations
      end
    end
  end
end
