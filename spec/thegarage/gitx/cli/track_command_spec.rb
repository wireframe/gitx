require 'spec_helper'
require 'thegarage/gitx/cli/track_command'

describe Thegarage::Gitx::Cli::TrackCommand do
  let(:args) { [] }
  let(:options) { {} }
  let(:config) do
    {
      pretend: true
    }
  end
  let(:cli) { Thegarage::Gitx::Cli::TrackCommand.new(args, options, config) }
  let(:branch) { double('fake branch', name: 'feature-branch') }

  before do
    allow(cli).to receive(:current_branch).and_return(branch)
  end

  describe '#track' do
    before do
      allow(cli).to receive(:say)

      expect(cli).to receive(:run_cmd).with('git pull origin feature-branch', allow_failure: true).ordered
      expect(cli).to receive(:run_cmd).with('git pull origin master').ordered
      expect(cli).to receive(:run_cmd).with('git push origin HEAD').ordered

      cli.track
    end
    it 'runs expected commands' do
      should meet_expectations
    end
  end
end
