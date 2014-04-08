require 'spec_helper'
require 'thegarage/gitx/cli/release_command'

describe Thegarage::Gitx::Cli::ReleaseCommand do
  let(:args) { [] }
  let(:options) { {} }
  let(:config) do
    {
      pretend: true
    }
  end
  let(:cli) { Thegarage::Gitx::Cli::ReleaseCommand.new(args, options, config) }
  let(:branch) { double('fake branch', name: 'feature-branch') }

  before do
    allow(cli).to receive(:current_branch).and_return(branch)
  end

  describe '#release' do
    context 'when user rejects release' do
      before do
        expect(cli).to receive(:yes?).and_return(false)
        expect(cli).to_not receive(:run_cmd)

        cli.release
      end
      it 'only runs update commands' do
        should meet_expectations
      end
    end
    context 'when user confirms release' do
      let(:fake_update_command) { double('fake update command', update: nil) }
      let(:fake_integrate_command) { double('fake integrate command') }
      let(:fake_cleanup_command) { double('fake cleanup command', cleanup: nil) }
      before do
        expect(Thegarage::Gitx::Cli::UpdateCommand).to receive(:new).and_return(fake_update_command)
        expect(Thegarage::Gitx::Cli::IntegrateCommand).to receive(:new).and_return(fake_integrate_command)
        expect(Thegarage::Gitx::Cli::CleanupCommand).to receive(:new).and_return(fake_cleanup_command)

        expect(fake_integrate_command).to receive(:integrate).with('staging')

        expect(cli).to receive(:yes?).and_return(true)

        expect(cli).to receive(:run_cmd).with("git checkout master").ordered
        expect(cli).to receive(:run_cmd).with("git pull origin master").ordered
        expect(cli).to receive(:run_cmd).with("git pull . feature-branch").ordered
        expect(cli).to receive(:run_cmd).with("git push origin HEAD").ordered

        cli.release
      end
      it 'runs expected commands' do
        should meet_expectations
      end
    end
  end
end
