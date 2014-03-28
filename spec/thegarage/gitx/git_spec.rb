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

  describe '#integrate' do
    context 'when target branch is ommitted' do
      before do
        expect(subject).to receive(:update)

        expect(runner).to receive(:run_cmd).with("git branch -D staging", allow_failure: true).ordered
        expect(runner).to receive(:run_cmd).with("git fetch origin").ordered
        expect(runner).to receive(:run_cmd).with("git checkout staging").ordered
        expect(runner).to receive(:run_cmd).with("git pull . feature-branch").ordered
        expect(runner).to receive(:run_cmd).with("git push origin HEAD").ordered
        expect(runner).to receive(:run_cmd).with("git checkout feature-branch").ordered
        expect(runner).to receive(:run_cmd).with("git checkout feature-branch").ordered

        subject.integrate
      end
      it 'defaults to staging branch' do
        should meet_expectations
      end
    end
    context 'when target branch == prototype' do
      before do
        expect(subject).to receive(:update)

        expect(runner).to receive(:run_cmd).with("git branch -D prototype", allow_failure: true).ordered
        expect(runner).to receive(:run_cmd).with("git fetch origin").ordered
        expect(runner).to receive(:run_cmd).with("git checkout prototype").ordered
        expect(runner).to receive(:run_cmd).with("git pull . feature-branch").ordered
        expect(runner).to receive(:run_cmd).with("git push origin HEAD").ordered
        expect(runner).to receive(:run_cmd).with("git checkout feature-branch").ordered
        expect(runner).to receive(:run_cmd).with("git checkout feature-branch").ordered

        subject.integrate 'prototype'
      end
      it 'runs expected commands' do
        should meet_expectations
      end
    end
    context 'when target branch != staging || prototype' do
      it 'raises an error' do
        expect(subject).to receive(:update)

        expect { subject.integrate('some-other-branch') }.to raise_error(/Only aggregate branches are allowed for integration/)
      end
    end
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

  describe '#buildtag' do
    let(:env_travis_branch) { nil }
    let(:env_travis_pull_request) { nil }
    let(:env_travis_build_number) { nil }
    before do
      ENV['TRAVIS_BRANCH'] = env_travis_branch
      ENV['TRAVIS_PULL_REQUEST'] = env_travis_pull_request
      ENV['TRAVIS_BUILD_NUMBER'] = env_travis_build_number
    end
    context 'when ENV[\'TRAVIS_BRANCH\'] is nil' do
      it 'raises Unknown Branch error' do
        expect { subject.buildtag }.to raise_error "Unknown branch. ENV['TRAVIS_BRANCH'] is required."
      end
    end
    context 'when the travis branch is master and the travis pull request is not false' do
      let(:env_travis_branch) { 'master' }
      let(:env_travis_pull_request) { '45' }
      before do
        expect(shell).to receive(:say).with("Skipping creation of tag for pull request: #{ENV['TRAVIS_PULL_REQUEST']}")
        subject.buildtag
      end
      it 'tells us that it is skipping the creation of the tag' do
        should meet_expectations
      end
    end
    context 'when the travis branch is NOT master and is not a pull request' do
      let(:env_travis_branch) { 'random-branch' }
      let(:env_travis_pull_request) { 'false' }
      before do
        expect(shell).to receive(:say).with(/Cannot create build tag for branch: #{ENV['TRAVIS_BRANCH']}/)
        subject.buildtag
      end
      it 'tells us that the branch is not supported' do
        should meet_expectations
      end
    end
    context 'when the travis branch is master and not a pull request' do
      let(:env_travis_branch) { 'master' }
      let(:env_travis_pull_request) { 'false' }
      let(:env_travis_build_number) { '24' }
      before do
        Timecop.freeze(Time.utc(2013, 10, 30, 10, 21, 28)) do
          expect(runner).to receive(:run_cmd).with("git tag build-master-2013-10-30-10-21-28 -a -m 'Generated tag from TravisCI build 24'").ordered
          expect(runner).to receive(:run_cmd).with("git push origin build-master-2013-10-30-10-21-28").ordered
          subject.buildtag
        end
      end
      it 'creates a tag for the branch and push it to github' do
        should meet_expectations
      end
    end
  end
end
