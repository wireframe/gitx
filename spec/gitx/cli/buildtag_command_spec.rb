require 'spec_helper'
require 'gitx/cli/buildtag_command'

describe Gitx::Cli::BuildtagCommand do
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

  describe '#buildtag' do
    context 'when options[:branch] is NOT set' do
      it 'defaults to current branch (feature-branch)' do
        expect { cli.buildtag }.to raise_error(/Branch must be one of the supported taggable branches/)
      end
    end
    context 'when options[:branch] is NOT master or staging' do
      let(:options) do
        {
          branch: 'feature-branch'
        }
      end
      it 'raises unsupported branch error' do
        expect { cli.buildtag }.to raise_error(/Branch must be one of the supported taggable branches/)
      end
    end
    context 'when options[:branch] is master' do
      let(:options) do
        {
          branch: 'master'
        }
      end
      before do
        Timecop.freeze(Time.utc(2013, 10, 30, 10, 21, 28)) do
          expect(executor).to receive(:execute).with('git', 'tag', 'builds/master/2013-10-30-10-21-28', '--annotate', '--message', '[gitx] buildtag for master').ordered
          expect(executor).to receive(:execute).with('git', 'push', 'origin', 'builds/master/2013-10-30-10-21-28').ordered
          cli.buildtag
        end
      end
      it 'creates a tag for the branch and push it to github' do
        should meet_expectations
      end
    end
    context 'when options[:message] is passed' do
      let(:options) do
        {
          branch: 'master',
          message: 'custom git commit message'
        }
      end
      before do
        Timecop.freeze(Time.utc(2013, 10, 30, 10, 21, 28)) do
          expect(executor).to receive(:execute).with('git', 'tag', 'builds/master/2013-10-30-10-21-28', '--annotate', '--message', 'custom git commit message').ordered
          expect(executor).to receive(:execute).with('git', 'push', 'origin', 'builds/master/2013-10-30-10-21-28').ordered
          cli.buildtag
        end
      end
      it 'creates a tag for the branch and push it to github' do
        should meet_expectations
      end
    end
  end
end
