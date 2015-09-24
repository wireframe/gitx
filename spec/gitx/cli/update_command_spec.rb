require 'spec_helper'
require 'gitx/cli/update_command'

describe Gitx::Cli::UpdateCommand do
  let(:args) { [] }
  let(:options) { {} }
  let(:config) do
    {
      pretend: true
    }
  end
  let(:cli) { described_class.new(args, options, config) }
  let(:branch) { double('fake branch', name: 'feature-branch') }
  let(:repo) { cli.send(:repo) }
  let(:executor) { cli.send(:executor) }
  let(:remote_branch_names) { ['origin/feature-branch'] }

  before do
    allow(cli).to receive(:current_branch).and_return(branch)
    branches = double('fake branches')
    allow(branches).to receive(:each_name).with(:remote).and_return(remote_branch_names)
    allow(repo).to receive(:branches).and_return(branches)
  end

  describe '#update' do
    context 'when no merge conflicts occur' do
      before do
        allow(cli).to receive(:say)

        expect(executor).to receive(:execute).with('git', 'pull', 'origin', 'feature-branch').ordered
        expect(executor).to receive(:execute).with('git', 'pull', 'origin', 'master').ordered
        expect(executor).to receive(:execute).with('git', 'push', 'origin', 'HEAD').ordered

        cli.update
      end
      it 'runs expected commands' do
        should meet_expectations
      end
    end
    context 'when merge conflicts occur when pulling remote feature-branch' do
      before do
        allow(cli).to receive(:say)

        expect(executor).to receive(:execute).with('git', 'pull', 'origin', 'feature-branch').and_raise('merge error').ordered

        expect { cli.update }.to raise_error(Gitx::Cli::BaseCommand::MergeError, 'Merge Conflict Occurred. Please fix merge conflict and rerun the update command')
      end
      it 'raises error' do
        should meet_expectations
      end
    end
    context 'when merge conflicts occur when pulling remote master branch' do
      before do
        allow(cli).to receive(:say)

        expect(executor).to receive(:execute).with('git', 'pull', 'origin', 'feature-branch').ordered
        expect(executor).to receive(:execute).with('git', 'pull', 'origin', 'master').and_raise('merge error occurred').ordered

        expect { cli.update }.to raise_error(Gitx::Cli::BaseCommand::MergeError, 'Merge Conflict Occurred. Please fix merge conflict and rerun the update command')
      end
      it 'raises error' do
        should meet_expectations
      end
    end
    context 'when feature-branch does not exist remotely' do
      let(:remote_branch_names) { [] }
      before do
        allow(cli).to receive(:say)

        expect(executor).not_to receive(:execute).with('git', 'pull', 'origin', 'feature-branch')
        expect(executor).to receive(:execute).with('git', 'pull', 'origin', 'master').ordered

        cli.update
      end
      it 'skips pulling from feature branch' do
        should meet_expectations
      end
    end
  end
end
