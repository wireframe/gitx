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
  let(:branch) { double('fake branch', name: 'feature-branch') }
  let(:remote_branches) { 'merged-remote-feature' }
  let(:local_branches) { 'merged-local-feature' }

  before do
    allow(cli).to receive(:current_branch).and_return(branch)
  end

  describe '#cleanup' do
    before do
      allow(cli).to receive(:say)

      expect(executor).to receive(:execute).with('git', 'checkout', 'master').ordered
      expect(executor).to receive(:execute).with('git', 'pull').ordered
      expect(executor).to receive(:execute).with('git', 'remote', 'prune', 'origin').ordered
      expect(executor).to receive(:execute).with('git', 'branch', '--remote', '--merged').and_return(remote_branches).ordered
      expect(executor).to receive(:execute).with('git', 'push', 'origin', '--delete', 'merged-remote-feature').ordered
      expect(executor).to receive(:execute).with('git', 'branch', '--merged').and_return(local_branches).ordered
      expect(executor).to receive(:execute).with('git', 'branch', '--delete', 'merged-local-feature').ordered

      cli.cleanup
    end
    it 'runs expected commands' do
      should meet_expectations
    end
  end
end
