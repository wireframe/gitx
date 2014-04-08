require 'spec_helper'
require 'timecop'

describe Thegarage::Gitx::Git do
  let(:runner) { double('fake runner') }
  let(:shell) { double('fake shell', say: nil) }
  let(:branch) { double('fake git branch', name: 'feature-branch') }
  subject { Thegarage::Gitx::Git.new(shell, runner) }

  # default current branch to: feature-branch
  before do
    allow(subject).to receive(:current_branch).and_return(branch)
  end

  describe '#release' do
    it 'merges feature branch into master' do
      expect(subject).to receive(:update)

      expect(runner).to receive(:run_cmd).with("git checkout master").ordered
      expect(runner).to receive(:run_cmd).with("git pull origin master").ordered
      expect(runner).to receive(:run_cmd).with("git pull . feature-branch").ordered
      expect(runner).to receive(:run_cmd).with("git push origin HEAD").ordered

      expect(subject).to receive(:integrate).with('staging')
      expect(subject).to receive(:cleanup)

      subject.release
    end
  end

  describe '#nuke' do
    context 'when target branch == prototype and head is a valid buildtag' do
      let(:buildtag) { 'build-master-2013-10-01-01' }
      before do
        expect(runner).to receive(:run_cmd).with("git checkout master").ordered
        expect(runner).to receive(:run_cmd).with("git branch -D prototype", allow_failure: true).ordered
        expect(runner).to receive(:run_cmd).with("git push origin --delete prototype", allow_failure: true).ordered
        expect(runner).to receive(:run_cmd).with("git checkout -b prototype build-master-2013-10-01-01").ordered
        expect(runner).to receive(:run_cmd).with("git push origin prototype").ordered
        expect(runner).to receive(:run_cmd).with("git branch --set-upstream-to origin/prototype").ordered
        expect(runner).to receive(:run_cmd).with("git checkout master").ordered

        subject.nuke 'prototype', buildtag
      end
      it 'runs expected commands' do
        should meet_expectations
      end
    end
    context 'when target branch == staging and head is a valid buildtag' do
      let(:buildtag) { 'build-master-2013-10-02-02' }
      before do
        expect(runner).to receive(:run_cmd).with("git checkout master").ordered
        expect(runner).to receive(:run_cmd).with("git branch -D staging", allow_failure: true).ordered
        expect(runner).to receive(:run_cmd).with("git push origin --delete staging", allow_failure: true).ordered
        expect(runner).to receive(:run_cmd).with("git checkout -b staging build-master-2013-10-02-02").ordered
        expect(runner).to receive(:run_cmd).with("git push origin staging").ordered
        expect(runner).to receive(:run_cmd).with("git branch --set-upstream-to origin/staging").ordered
        expect(runner).to receive(:run_cmd).with("git checkout master").ordered

        subject.nuke 'staging', buildtag
      end
      it 'runs expected commands' do
        should meet_expectations
      end
    end
    context 'when target branch != staging || prototype' do
      it 'raises error' do
        expect { subject.nuke('not-an-integration-branch', 'master') }.to raise_error(/Only aggregate branches are allowed to be reset/)
      end
    end
  end

  describe '#current_build_tag' do
    context 'when multiple build tags returned' do
      let(:buildtags) { %w( build-master-2013-01-01-01 build-master-2013-01-01-02 ).join("\n") }
      it 'returns the last one' do
        expect(runner).to receive(:run_cmd).with("git fetch --tags").ordered
        expect(runner).to receive(:run_cmd).with("git tag -l 'build-master-*'").and_return(buildtags).ordered

        result = subject.current_build_tag 'master'
        expect(result).to eq 'build-master-2013-01-01-02'
      end
    end
    context 'when no known good build tag found' do
      let(:buildtags) { '' }
      it 'raises error' do
        expect(runner).to receive(:run_cmd).with("git fetch --tags").ordered
        expect(runner).to receive(:run_cmd).with("git tag -l 'build-master-*'").and_return(buildtags).ordered

        expect { subject.current_build_tag('master') }.to raise_error(/No known good tag found for branch/)
      end
    end
  end

end
