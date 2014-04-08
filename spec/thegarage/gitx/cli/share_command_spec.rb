require 'spec_helper'
require 'thegarage/gitx/cli/share_command'

describe Thegarage::Gitx::Cli::ShareCommand do
  let(:args) { [] }
  let(:options) { {} }
  let(:config) do
    {
      pretend: true
    }
  end
  let(:cli) { Thegarage::Gitx::Cli::ShareCommand.new(args, options, config) }
  let(:branch) { double('fake branch', name: 'feature-branch') }

  before do
    allow(cli).to receive(:current_branch).and_return(branch)
  end

  describe '#share' do
    before do
      allow(cli).to receive(:say)

      expect(cli).to receive(:run_cmd).with('git push origin feature-branch').ordered
      expect(cli).to receive(:run_cmd).with('git branch --set-upstream-to origin/feature-branch').ordered

      cli.share
    end
    it 'runs expected commands' do
      should meet_expectations
    end
  end
end
