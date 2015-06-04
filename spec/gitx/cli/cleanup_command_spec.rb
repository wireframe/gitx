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
  let(:cli) { Gitx::Cli::CleanupCommand.new(args, options, config) }
  let(:branch) { double('fake branch', name: 'feature-branch') }

  before do
    allow(cli).to receive(:current_branch).and_return(branch)
  end

  describe '#cleanup' do
    before do
      allow(cli).to receive(:say)

      expect(cli).to receive(:run_cmd).with('git checkout master').ordered
      expect(cli).to receive(:run_cmd).with('git pull').ordered
      expect(cli).to receive(:run_cmd).with('git remote prune origin').ordered
      expect(cli).to receive(:run_cmd).with('git branch -r --merged').and_return('merged-remote-feature').ordered
      expect(cli).to receive(:run_cmd).with('git push origin --delete merged-remote-feature').ordered
      expect(cli).to receive(:run_cmd).with('git branch --merged').and_return('merged-local-feature').ordered
      expect(cli).to receive(:run_cmd).with('git branch -d merged-local-feature').ordered

      cli.cleanup
    end
    it 'runs expected commands' do
      should meet_expectations
    end
  end
end
