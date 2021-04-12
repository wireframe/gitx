require 'spec_helper'
require 'gitx/cli/nuke_command'

describe Gitx::Cli::NukeCommand do
  let(:args) { [] }
  let(:options) { {} }
  let(:config) do
    {
      pretend: true
    }
  end
  let(:cli) { described_class.new(args, options, config) }
  let(:executor) { cli.send(:executor) }
  let(:branch) { double('fake branch', name: 'feature-branch') }
  let(:tags) { [] }
  let(:workdir) { '.' }
  let(:repo) { double(:repo, workdir: workdir, tags: tags) }

  before do
    allow(cli).to receive(:current_branch).and_return(branch)
    allow(cli).to receive(:repo).and_return(repo)
  end

  describe '#nuke' do
    context 'when target branch == prototype and --destination == main' do
      let(:options) do
        {
          destination: good_branch
        }
      end
      let(:good_branch) { 'main' }
      let(:bad_branch) { 'prototype' }
      let(:buildtag) { double(:tag, name: 'builds/main/2013-10-01-01') }
      let(:tags) { [buildtag] }
      before do
        expect(cli).to receive(:yes?).and_return(true)

        expect(executor).to receive(:execute).with('git', 'fetch', '--tags').ordered
        expect(executor).to receive(:execute).with('git', 'checkout', 'main').ordered
        expect(executor).to receive(:execute).with('git', 'branch', '--delete', '--force', 'prototype').ordered
        expect(executor).to receive(:execute).with('git', 'push', 'origin', '--delete', 'prototype').ordered
        expect(executor).to receive(:execute).with('git', 'checkout', '-b', 'prototype', 'builds/main/2013-10-01-01').ordered
        expect(executor).to receive(:execute).with('git', 'share').ordered
        expect(executor).to receive(:execute).with('git', 'checkout', 'main').ordered

        cli.nuke bad_branch
      end
      it 'runs expected commands' do
        should meet_expectations
      end
    end
    context 'when target branch == prototype and destination prompt == nil' do
      let(:good_branch) { 'main' }
      let(:bad_branch) { 'prototype' }
      let(:buildtag) { double(:tag, name: 'builds/main/2013-10-01-01') }
      let(:tags) { [buildtag] }
      before do
        expect(cli).to receive(:ask).and_return(good_branch)
        expect(cli).to receive(:yes?).and_return(true)

        expect(executor).to receive(:execute).with('git', 'fetch', '--tags').ordered
        expect(executor).to receive(:execute).with('git', 'checkout', 'main').ordered
        expect(executor).to receive(:execute).with('git', 'branch', '--delete', '--force', 'prototype').ordered
        expect(executor).to receive(:execute).with('git', 'push', 'origin', '--delete', 'prototype').ordered
        expect(executor).to receive(:execute).with('git', 'checkout', '-b', 'prototype', 'builds/main/2013-10-01-01').ordered
        expect(executor).to receive(:execute).with('git', 'share').ordered
        expect(executor).to receive(:execute).with('git', 'checkout', 'main').ordered

        cli.nuke 'prototype'
      end
      it 'defaults to prototype and should run expected commands' do
        should meet_expectations
      end
    end
    context 'when user does not confirm nuking the target branch' do
      let(:buildtag) { double(:tag, name: 'builds/main/2013-10-01-01') }
      let(:tags) { [buildtag] }
      before do
        expect(cli).to receive(:ask).and_return('main')
        expect(cli).to receive(:yes?).and_return(false)

        expect(executor).to receive(:execute).with('git', 'fetch', '--tags').ordered
        expect(executor).to_not receive(:execute).with('git', 'checkout', 'main').ordered

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
      let(:good_branch) { 'main' }
      let(:bad_branch) { 'prototype' }
      let(:buildtags) { '' }
      it 'raises error' do
        expect(executor).to receive(:execute).with('git', 'fetch', '--tags').ordered
        expect { cli.nuke('prototype') }.to raise_error(/No known good tag found for branch/)
      end
    end
    context 'when database migrations exist and user cancels operation' do
      let(:buildtag) { double(:tag, name: 'builds/main/2013-10-01-01') }
      let(:tags) { [buildtag] }
      let(:good_branch) { 'main' }
      let(:bad_branch) { 'prototype' }
      let(:migrations) do
        %w[db/migrate/20140715194946_create_users.rb db/migrate/20140730063034_update_user_account.rb].join("\n")
      end
      before do
        FileUtils.mkdir_p('db/migrate')

        expect(executor).to receive(:execute).with('git', 'fetch', '--tags').ordered
        expect(cli).to receive(:ask).and_return(good_branch)
        expect(cli).to receive(:yes?).with('Reset prototype to builds/main/2013-10-01-01? (y/n)', :green).and_return(true)
        expect(executor).to receive(:execute).with('git', 'diff', 'builds/main/2013-10-01-01...prototype', '--name-only', 'db/migrate').and_return(migrations)
        expect(cli).to receive(:yes?).with('Are you sure you want to nuke prototype? (y/n) ', :green).and_return(false)

        cli.nuke 'prototype'
      end
      after do
        FileUtils.rm_rf('db/migrate')
      end
      it 'prompts for nuke confirmation' do
        should meet_expectations
      end
    end
    context 'when database migrations exist and user approves operation' do
      let(:buildtag) { double(:tag, name: 'builds/main/2013-10-01-01') }
      let(:tags) { [buildtag] }
      let(:good_branch) { 'main' }
      let(:bad_branch) { 'prototype' }
      let(:migrations) do
        %w[db/migrate/20140715194946_create_users.rb db/migrate/20140730063034_update_user_account.rb].join("\n")
      end
      before do
        FileUtils.mkdir_p('db/migrate')

        expect(cli).to receive(:ask).and_return(good_branch)
        expect(cli).to receive(:yes?).with('Reset prototype to builds/main/2013-10-01-01? (y/n)', :green).and_return(true)
        expect(executor).to receive(:execute).with('git', 'diff', 'builds/main/2013-10-01-01...prototype', '--name-only', 'db/migrate').and_return(migrations)
        expect(cli).to receive(:yes?).with('Are you sure you want to nuke prototype? (y/n) ', :green).and_return(true)

        expect(executor).to receive(:execute).with('git', 'fetch', '--tags').ordered
        expect(executor).to receive(:execute).with('git', 'checkout', 'main').ordered
        expect(executor).to receive(:execute).with('git', 'branch', '--delete', '--force', 'prototype').ordered
        expect(executor).to receive(:execute).with('git', 'push', 'origin', '--delete', 'prototype').ordered
        expect(executor).to receive(:execute).with('git', 'checkout', '-b', 'prototype', 'builds/main/2013-10-01-01').ordered
        expect(executor).to receive(:execute).with('git', 'share').ordered
        expect(executor).to receive(:execute).with('git', 'checkout', 'main').ordered

        cli.nuke 'prototype'
      end
      after do
        FileUtils.rm_rf('db/migrate')
      end
      it 'prompts for nuke confirmation' do
        should meet_expectations
      end
    end
  end
end
