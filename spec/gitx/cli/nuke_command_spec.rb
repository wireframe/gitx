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

        expect(executor).to receive(:execute).with('git', 'checkout', 'master').ordered
        expect(executor).to receive(:execute).with('git', 'branch', '--delete', '--force', 'prototype').ordered
        expect(executor).to receive(:execute).with('git', 'push', 'origin', '--delete', 'prototype').ordered
        expect(executor).to receive(:execute).with('git', 'checkout', '-b', 'prototype', 'build-master-2013-10-01-01').ordered
        expect(executor).to receive(:execute).with('git', 'share').ordered
        expect(executor).to receive(:execute).with('git', 'checkout', 'master').ordered

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

        expect(executor).to receive(:execute).with('git', 'checkout', 'master').ordered
        expect(executor).to receive(:execute).with('git', 'branch', '--delete', '--force', 'prototype').ordered
        expect(executor).to receive(:execute).with('git', 'push', 'origin', '--delete', 'prototype').ordered
        expect(executor).to receive(:execute).with('git', 'checkout', '-b', 'prototype', 'build-master-2013-10-01-01').ordered
        expect(executor).to receive(:execute).with('git', 'share').ordered
        expect(executor).to receive(:execute).with('git', 'checkout', 'master').ordered

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

        expect(executor).to_not receive(:execute)

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
        expect(executor).to receive(:execute).with('git', 'fetch', '--tags').ordered
        expect(executor).to receive(:execute).with('git', 'tag', '--list', 'build-master-*').and_return(buildtags).ordered

        expect { cli.nuke('prototype') }.to raise_error(/No known good tag found for branch/)
      end
    end
    context 'when database migrations exist and user cancels operation' do
      let(:buildtag) { 'build-master-2013-10-01-01' }
      let(:good_branch) { 'master' }
      let(:bad_branch) { 'prototype' }
      let(:migrations) do
        %w( db/migrate/20140715194946_create_users.rb db/migrate/20140730063034_update_user_account.rb ).join("\n")
      end
      before do
        FileUtils.mkdir_p('db/migrate')

        expect(cli).to receive(:current_build_tag).with(good_branch).and_return(buildtag)

        expect(cli).to receive(:ask).and_return(good_branch)
        expect(cli).to receive(:yes?).with('Reset prototype to build-master-2013-10-01-01? (y/n)', :green).and_return(true)
        expect(executor).to receive(:execute).with('git', 'diff', 'build-master-2013-10-01-01...prototype', '--name-only', 'db/migrate').and_return(migrations)
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
      let(:buildtag) { 'build-master-2013-10-01-01' }
      let(:good_branch) { 'master' }
      let(:bad_branch) { 'prototype' }
      let(:migrations) do
        %w( db/migrate/20140715194946_create_users.rb db/migrate/20140730063034_update_user_account.rb ).join("\n")
      end
      before do
        FileUtils.mkdir_p('db/migrate')

        expect(cli).to receive(:current_build_tag).with(good_branch).and_return(buildtag)

        expect(cli).to receive(:ask).and_return(good_branch)
        expect(cli).to receive(:yes?).with('Reset prototype to build-master-2013-10-01-01? (y/n)', :green).and_return(true)
        expect(executor).to receive(:execute).with('git', 'diff', 'build-master-2013-10-01-01...prototype', '--name-only', 'db/migrate').and_return(migrations)
        expect(cli).to receive(:yes?).with('Are you sure you want to nuke prototype? (y/n) ', :green).and_return(true)

        expect(executor).to receive(:execute).with('git', 'checkout', 'master').ordered
        expect(executor).to receive(:execute).with('git', 'branch', '--delete', '--force', 'prototype').ordered
        expect(executor).to receive(:execute).with('git', 'push', 'origin', '--delete', 'prototype').ordered
        expect(executor).to receive(:execute).with('git', 'checkout', '-b', 'prototype', 'build-master-2013-10-01-01').ordered
        expect(executor).to receive(:execute).with('git', 'share').ordered
        expect(executor).to receive(:execute).with('git', 'checkout', 'master').ordered

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
