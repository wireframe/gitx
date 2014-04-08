require 'spec_helper'

describe Thegarage::Gitx::CLI do
  let(:args) { [] }
  let(:options) { {} }
  let(:config) do
    {
      pretend: true
    }
  end
  let(:cli) { Thegarage::Gitx::CLI.new(args, options, config) }
  let(:git) { double('fake git') }
  let(:runner) { double('fake runner') }
  let(:branch) { double('fake branch', name: 'feature-branch') }

  before do
    allow(cli).to receive(:git).and_return(git)
    allow(cli).to receive(:runner).and_return(runner)
    allow(git).to receive(:current_branch).and_return(branch)
  end

  describe '#release' do
    context 'when user rejects release' do
      before do
        expect(cli).to receive(:yes?).and_return(false)

        expect(git).to_not receive(:release)

        cli.release
      end
      it 'only runs update commands' do
        should meet_expectations
      end
    end
    context 'when user confirms release' do
      before do
        expect(cli).to receive(:yes?).and_return(true)
        expect(git).to receive(:release)
        cli.release
      end
      it 'runs expected commands' do
        should meet_expectations
      end
    end
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

        expect(git).to receive(:current_build_tag).with(good_branch).and_return(buildtag)
        expect(git).to receive(:nuke).with(bad_branch, buildtag)

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

        expect(git).to receive(:current_build_tag).with(good_branch).and_return(buildtag)
        expect(git).to receive(:nuke).with(bad_branch, buildtag)

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

        expect(git).to receive(:current_build_tag).with('master').and_return(buildtag)
        expect(git).to_not receive(:nuke)

        cli.nuke 'prototype'
      end
      it 'runs expected commands' do
        should meet_expectations
      end
    end
  end
end
