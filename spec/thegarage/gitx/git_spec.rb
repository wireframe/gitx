require 'spec_helper'
require 'timecop'

describe Thegarage::Gitx::Git do
  let(:runner) { double('fake runner') }
  let(:shell) { double('fake shell') }
  let(:current_branch) { double('fake git branch', name: 'feature-branch') }
  subject { Thegarage::Gitx::Worker.new(shell, runner) }

  # default current branch to: feature-branch
  before do
    allow(subject).to receive(:current_branch).and_return(current_branch)
  end

  describe '#update' do
    before do
      allow(shell).to receive(:say)

      expect(runner).to receive(:run_cmd).with('git pull origin feature-branch', allow_failure: true).ordered
      expect(runner).to receive(:run_cmd).with('git pull origin master').ordered
      expect(runner).to receive(:run_cmd).with('git push origin HEAD').ordered

      subject.update
    end
    it 'runs expected commands' do
      should meet_expectations
    end
  end

  describe '#track' do
    before do
      expect(runner).to receive(:run_cmd).with('git branch --set-upstream-to origin/feature-branch').ordered

      subject.track
    end
    it 'runs expected commands' do
      should meet_expectations
    end
  end

  describe '#share' do
    before do
      expect(runner).to receive(:run_cmd).with('git push origin feature-branch').ordered
      expect(runner).to receive(:run_cmd).with('git branch --set-upstream-to origin/feature-branch').ordered

      subject.share
    end
    it 'runs expected commands' do
      should meet_expectations
    end
  end
end
