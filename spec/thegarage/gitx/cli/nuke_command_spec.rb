require 'spec_helper'
require 'thegarage/gitx/cli/nuke_command'

describe Thegarage::Gitx::Cli::NukeCommand do
  let(:args) { [] }
  let(:options) { {} }
  let(:config) do
    {
      pretend: true
    }
  end
  let(:cli) { Thegarage::Gitx::Cli::NukeCommand.new(args, options, config) }
  let(:branch) { double('fake branch', name: 'feature-branch') }

  before do
    allow(cli).to receive(:current_branch).and_return(branch)
  end

  describe '#nuke' do
    context 'when target branch == prototype and --destination == master' do
      let(:options) do
        {
          destination: good_branch
        }
      end
      let(:good_branch) { 'master' }
      let(:bad_branch) { 'prototype' }
      let(:buildtag) { 'build-master-2013-10-01-01' }
      before do
        expect(cli).to receive(:yes?).and_return(true)

        expect(cli).to receive(:current_build_tag).with(good_branch).and_return(buildtag)

        expect(cli).to receive(:run_cmd).with("git checkout master").ordered
        expect(cli).to receive(:run_cmd).with("git branch -D prototype", allow_failure: true).ordered
        expect(cli).to receive(:run_cmd).with("git push origin --delete prototype", allow_failure: true).ordered
        expect(cli).to receive(:run_cmd).with("git checkout -b prototype build-master-2013-10-01-01").ordered
        expect(cli).to receive(:run_cmd).with("git push origin prototype").ordered
        expect(cli).to receive(:run_cmd).with("git branch --set-upstream-to origin/prototype").ordered
        expect(cli).to receive(:run_cmd).with("git checkout master").ordered

        cli.nuke bad_branch
      end
      it 'runs expected commands' do
        should meet_expectations
      end
    end
    context 'when target branch == prototype and destination prompt == nil' do
      let(:good_branch) { 'master' }
      let(:bad_branch) { 'prototype' }
      let(:buildtag) { 'build-master-2013-10-01-01' }
      before do
        expect(cli).to receive(:ask).and_return(good_branch)
        expect(cli).to receive(:yes?).and_return(true)

        expect(cli).to receive(:current_build_tag).with(good_branch).and_return(buildtag)

        expect(cli).to receive(:run_cmd).with("git checkout master").ordered
        expect(cli).to receive(:run_cmd).with("git branch -D prototype", allow_failure: true).ordered
        expect(cli).to receive(:run_cmd).with("git push origin --delete prototype", allow_failure: true).ordered
        expect(cli).to receive(:run_cmd).with("git checkout -b prototype build-master-2013-10-01-01").ordered
        expect(cli).to receive(:run_cmd).with("git push origin prototype").ordered
        expect(cli).to receive(:run_cmd).with("git branch --set-upstream-to origin/prototype").ordered
        expect(cli).to receive(:run_cmd).with("git checkout master").ordered

        cli.nuke 'prototype'
      end
      it 'defaults to prototype and should run expected commands' do
        should meet_expectations
      end
    end
    context 'when user does not confirm nuking the target branch' do
      let(:buildtag) { 'build-master-2013-10-01-01' }
      before do
        expect(cli).to receive(:ask).and_return('master')
        expect(cli).to receive(:yes?).and_return(false)

        expect(cli).to receive(:current_build_tag).with('master').and_return(buildtag)

        expect(cli).to_not receive(:run_cmd)

        cli.nuke 'prototype'
      end
      it 'runs expected commands' do
        should meet_expectations
      end
    end
    context 'when no valid buildtag is found' do
      let(:options) do
        {
          destination: good_branch
        }
      end
      let(:good_branch) { 'master' }
      let(:bad_branch) { 'prototype' }
      let(:buildtags) { '' }
      it 'raises error' do
        expect(cli).to receive(:run_cmd).with("git fetch --tags").ordered
        expect(cli).to receive(:run_cmd).with("git tag -l 'build-master-*'").and_return(buildtags).ordered

        expect { cli.nuke('prototype') }.to raise_error(/No known good tag found for branch/)
      end
    end
  end
end
