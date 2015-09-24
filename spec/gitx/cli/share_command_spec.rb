require 'spec_helper'
require 'gitx/cli/share_command'

describe Gitx::Cli::ShareCommand do
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

  before do
    allow(cli).to receive(:current_branch).and_return(branch)
  end

  describe '#share' do
    before do
      allow(cli).to receive(:say)

      expect(executor).to receive(:execute).with('git', 'push', 'origin', 'feature-branch').ordered
      expect(executor).to receive(:execute).with('git', 'branch', '--set-upstream-to', 'origin/feature-branch').ordered

      cli.share
    end
    it 'runs expected commands' do
      should meet_expectations
    end
  end
end
