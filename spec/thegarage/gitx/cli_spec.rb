require 'spec_helper'
require 'timecop'

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
  let(:github) { double('fake github') }
  let(:runner) { double('fake runner') }
  let(:branch) { double('fake branch', name: 'feature-branch') }

  before do
    allow(cli).to receive(:git).and_return(git)
    allow(cli).to receive(:runner).and_return(runner)
    allow(cli).to receive(:github).and_return(github)
    allow(git).to receive(:current_branch).and_return(branch)
  end

  describe '#update' do
    before do
      expect(git).to receive(:update)

      cli.update
    end
    it 'runs expected commands' do
      should meet_expectations
    end
  end

  describe '#integrate' do
    context 'when target branch is ommitted' do
      before do
        expect(git).to receive(:integrate).with('staging')

        cli.integrate
      end
      it 'defaults to staging branch' do
        should meet_expectations
      end
    end
    context 'when target branch == prototype' do
      before do
        expect(git).to receive(:integrate).with('prototype')

        cli.integrate 'prototype'
      end
      it 'runs expected commands' do
        should meet_expectations
      end
    end
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

  describe '#reviewrequest' do
    let(:pull_request) do
      {
        'html_url' => 'https://path/to/new/pull/request',
        'head' => {
          'ref' => 'branch_name'
        }
      }
    end
    context 'when pull request does not exist' do
      let(:authorization_token) { '123123' }
      let(:changelog) { '* made some fixes' }
      before do
        expect(github).to receive(:authorization_token).and_return(authorization_token)
        expect(github).to receive(:find_pull_request).and_return(nil)
        expect(github).to receive(:create_pull_request).and_return(pull_request)

        expect(git).to receive(:update)
        expect(runner).to receive(:run_cmd).with("git log master...feature-branch --no-merges --pretty=format:'* %s%n%b'").and_return("2013-01-01 did some stuff").ordered
        cli.reviewrequest
      end
      it 'creates github pull request' do
        should meet_expectations
      end
      it 'runs expected commands' do
        should meet_expectations
      end
    end
    context 'when authorization_token is missing' do
      let(:authorization_token) { nil }
      it do
        expect(github).to receive(:authorization_token).and_return(authorization_token)
        expect { cli.reviewrequest }.to raise_error(/token not found/)
      end
    end
    context 'when pull request already exists' do
      let(:authorization_token) { '123123' }
      before do
        expect(github).to receive(:authorization_token).and_return(authorization_token)
        expect(github).to receive(:find_pull_request).and_return(pull_request)
        expect(github).to_not receive(:create_pull_request)

        cli.reviewrequest
      end
      it 'does not create new pull request' do
        should meet_expectations
      end
    end
    context 'when --assignee option passed' do
      let(:options) do
        {
          assignee: 'johndoe'
        }
      end
      let(:authorization_token) { '123123' }
      before do
        expect(github).to receive(:authorization_token).and_return(authorization_token)
        expect(github).to receive(:find_pull_request).and_return(pull_request)
        expect(github).to receive(:assign_pull_request)

        cli.reviewrequest
      end
      it 'calls assign_pull_request method' do
        should meet_expectations
      end
    end
    context 'when --open flag passed' do
      let(:options) do
        {
          open: true
        }
      end
      let(:authorization_token) { '123123' }
      before do
        expect(github).to receive(:authorization_token).and_return(authorization_token)
        expect(github).to receive(:find_pull_request).and_return(pull_request)

        expect(runner).to receive(:run_cmd).with("open #{pull_request['html_url']}").ordered
        cli.reviewrequest
      end
      it 'runs open command with pull request url' do
        should meet_expectations
      end
    end
  end

  describe '#track' do
    it 'calls git.track' do
      expect(git).to receive(:track)
      cli.track
    end
  end

  describe '#share' do
    it 'calls git.share' do
      expect(git).to receive(:share)
      cli.share
    end
  end

  describe '#start' do
    context 'when user inputs branch that is valid' do
      it 'calls git.start' do
        expect(git).to receive(:valid_new_branch_name?).with('new-branch').and_return(true)
        expect(git).to receive(:start).with('new-branch')

        cli.start 'new-branch'
      end
    end
  end

  describe '#buildtag' do
    it 'calls git.buildtag' do
      expect(git).to receive(:buildtag)
      cli.buildtag
    end
  end
end
