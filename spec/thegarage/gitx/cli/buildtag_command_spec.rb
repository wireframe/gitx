require 'spec_helper'
require 'thegarage/gitx/cli/buildtag_command'

describe Thegarage::Gitx::Cli::BuildtagCommand do
  let(:args) { [] }
  let(:options) { {} }
  let(:config) do
    {
      pretend: true
    }
  end
  let(:cli) { Thegarage::Gitx::Cli::BuildtagCommand.new(args, options, config) }
  let(:branch) { double('fake branch', name: 'feature-branch') }

  before do
    allow(cli).to receive(:current_branch).and_return(branch)
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
        expect { cli.buildtag }.to raise_error "Unknown branch. ENV['TRAVIS_BRANCH'] is required."
      end
    end
    context 'when the travis branch is master and the travis pull request is not false' do
      let(:env_travis_branch) { 'master' }
      let(:env_travis_pull_request) { '45' }
      before do
        expect(cli).to receive(:say).with("Skipping creation of tag for pull request: #{ENV['TRAVIS_PULL_REQUEST']}")
        cli.buildtag
      end
      it 'tells us that it is skipping the creation of the tag' do
        should meet_expectations
      end
    end
    context 'when the travis branch is NOT master and is not a pull request' do
      let(:env_travis_branch) { 'random-branch' }
      let(:env_travis_pull_request) { 'false' }
      before do
        expect(cli).to receive(:say).with(/Cannot create build tag for branch: #{ENV['TRAVIS_BRANCH']}/)
        cli.buildtag
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
          expect(cli).to receive(:run_cmd).with("git tag build-master-2013-10-30-10-21-28 -a -m 'Generated tag from TravisCI build 24'").ordered
          expect(cli).to receive(:run_cmd).with("git push origin build-master-2013-10-30-10-21-28").ordered
          cli.buildtag
        end
      end
      it 'creates a tag for the branch and push it to github' do
        should meet_expectations
      end
    end
  end
end
