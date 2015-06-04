require 'spec_helper'
require 'gitx/cli/track_command'

describe Gitx::Cli::TrackCommand do
  let(:args) { [] }
  let(:options) { {} }
  let(:config) do
    {
      pretend: true
    }
  end
  let(:cli) { Gitx::Cli::TrackCommand.new(args, options, config) }
  let(:branch) { double('fake branch', name: 'feature-branch') }

  before do
    allow(cli).to receive(:current_branch).and_return(branch)
  end

  describe '#track' do
    before do
      allow(cli).to receive(:say)

      expect(cli).to receive(:run_cmd).with('git branch --set-upstream-to origin/feature-branch').ordered

      cli.track
    end
    it 'runs expected commands' do
      should meet_expectations
    end
  end
end
