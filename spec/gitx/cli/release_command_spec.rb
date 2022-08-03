require 'spec_helper'
require 'gitx/cli/release_command'

describe Gitx::Cli::ReleaseCommand do
  let(:args) { [] }
  let(:options) { {} }
  let(:config) do
    {
      pretend: true
    }
  end
  let(:cli) { described_class.new(args, options, config) }
  let(:branch) { double('fake branch', name: 'feature-branch') }
  let(:authorization_token) { '123123' }
  let(:repo) { cli.send(:repo) }
  let(:executor) { cli.send(:executor) }

  before do
    allow(cli).to receive(:current_branch).and_return(branch)
    allow(cli).to receive(:github_slug).and_return('wireframe/gitx')
  end

  describe '#release' do
    context 'when user rejects release' do
      before do
        expect(cli).to receive(:yes?).and_return(false)
        expect(executor).to_not receive(:execute)

        cli.release
      end
      it 'only runs update commands' do
        should meet_expectations
      end
    end
    context 'when user confirms release and pull request exists with non-success status' do
      before do
        expect(repo).to receive(:workdir).and_return(temp_dir)

        expect(cli).to receive(:yes?).with('Release feature-branch to main? (y/n)', :green).and_return(true)
        expect(cli).to receive(:yes?).with('Branch status is currently: failure.  Proceed with release? (y/n)', :red).and_return(false)
        allow(cli).to receive(:authorization_token).and_return(authorization_token)

        expect(executor).to receive(:execute).with('git', 'update').ordered
        expect(executor).to_not receive(:execute).with('git', 'checkout', 'main')
        expect(executor).to_not receive(:execute).with('git', 'pull', 'origin', 'main')
        expect(executor).to_not receive(:execute).with('git', 'merge', '--no-ff', '--message', "[gitx] Release feature-branch to main\n\nConnected to #10", 'feature-branch')
        expect(executor).to_not receive(:execute).with('git', 'push', 'origin', 'HEAD')

        VCR.use_cassette('pull_request_does_exist_with_failure_status') do
          cli.release
        end
      end
      it 'runs expected commands' do
        should meet_expectations
      end
    end
    context 'when user confirms release and pull request exists with success status with default config' do
      before do
        expect(repo).to receive(:workdir).and_return(temp_dir)

        expect(cli).to receive(:yes?).and_return(true)
        expect(cli).to_not receive(:label_pull_request)
        allow(cli).to receive(:authorization_token).and_return(authorization_token)

        expect(executor).to receive(:execute).with('git', 'checkout', 'feature-branch').ordered
        expect(executor).to receive(:execute).with('git', 'update').ordered
        expect(executor).to receive(:execute).with('git', 'checkout', 'main').ordered
        expect(executor).to receive(:execute).with('git', 'pull', 'origin', 'main').ordered
        expect(executor).to receive(:execute).with('git', 'merge', '--no-ff', '--message', "[gitx] Release feature-branch to main\n\nConnected to #10", 'feature-branch').ordered
        expect(executor).to receive(:execute).with('git', 'push', 'origin', 'HEAD').ordered
        expect(executor).to receive(:execute).with('git integrate --skip-pull-request').ordered

        VCR.use_cassette('pull_request_does_exist_with_success_status') do
          cli.release
        end
      end
      it 'runs expected commands' do
        should meet_expectations
      end
    end
    context 'when user confirms release and pull request exists with success status with custom after_release config' do
      let(:gitx_config) do
        {
          'after_release' => ['echo hello']
        }
      end
      before do
        expect(repo).to receive(:workdir).and_return(temp_dir)
        File.open(File.join(temp_dir, '.gitx.yml'), 'w') do |f|
          f.puts gitx_config.to_yaml
        end
        expect(cli).to receive(:yes?).and_return(true)
        allow(cli).to receive(:authorization_token).and_return(authorization_token)

        expect(executor).to receive(:execute).with('git', 'checkout', 'feature-branch').ordered
        expect(executor).to receive(:execute).with('git', 'update').ordered
        expect(executor).to receive(:execute).with('git', 'checkout', 'main').ordered
        expect(executor).to receive(:execute).with('git', 'pull', 'origin', 'main').ordered
        expect(executor).to receive(:execute).with('git', 'merge', '--no-ff', '--message', "[gitx] Release feature-branch to main\n\nConnected to #10", 'feature-branch').ordered
        expect(executor).to receive(:execute).with('git', 'push', 'origin', 'HEAD').ordered
        expect(executor).to receive(:execute).with('echo hello').ordered

        VCR.use_cassette('pull_request_does_exist_with_success_status') do
          cli.release
        end
      end
      it 'runs expected commands' do
        should meet_expectations
      end
    end
    context 'when target_branch is not nil and user confirms release and pull request exists with success status' do
      before do
        expect(repo).to receive(:workdir).and_return(temp_dir)

        expect(cli).to receive(:yes?).and_return(true)
        allow(cli).to receive(:authorization_token).and_return(authorization_token)

        expect(executor).to receive(:execute).with('git', 'checkout', 'feature-branch').ordered
        expect(executor).to receive(:execute).with('git', 'update').ordered
        expect(executor).to receive(:execute).with('git', 'checkout', 'main').ordered
        expect(executor).to receive(:execute).with('git', 'pull', 'origin', 'main').ordered
        expect(executor).to receive(:execute).with('git', 'merge', '--no-ff', '--message', "[gitx] Release feature-branch to main\n\nConnected to #10", 'feature-branch').ordered
        expect(executor).to receive(:execute).with('git', 'push', 'origin', 'HEAD').ordered
        expect(executor).to receive(:execute).with('git integrate --skip-pull-request').ordered

        VCR.use_cassette('pull_request_does_exist_with_success_status') do
          cli.release 'feature-branch'
        end
      end
      it 'runs expected commands' do
        should meet_expectations
      end
    end
    context 'when user confirms release and pull request does not exist' do
      let(:new_pull_request) do
        {
          html_url: 'https://path/to/html/pull/request',
          issue_url: 'https://api/path/to/issue/url',
          number: 10,
          head: {
            ref: 'branch_name'
          }
        }
      end
      before do
        expect(repo).to receive(:workdir).and_return(temp_dir)
        allow(cli).to receive(:authorization_token).and_return(authorization_token)
        allow(cli).to receive(:ask_editor).and_return('description')

        expect(cli).to receive(:yes?).with('Release feature-branch to main? (y/n)', :green).and_return(true)
        expect(cli).to receive(:yes?).with('Branch status is currently: pending.  Proceed with release? (y/n)', :red).and_return(true)

        expect(executor).to receive(:execute).with('git', 'checkout', 'feature-branch').ordered
        expect(executor).to receive(:execute).with('git', 'update').ordered
        expect(executor).to receive(:execute).with('git', 'checkout', 'feature-branch').ordered
        expect(executor).to receive(:execute).with('git', 'update').ordered
        expect(executor).to receive(:execute).with('git', 'log', 'origin/main...feature-branch', '--reverse', '--no-merges', '--pretty=format:* %B').and_return('2013-01-01 did some stuff').ordered
        expect(executor).to receive(:execute).with('git', 'checkout', 'main').ordered
        expect(executor).to receive(:execute).with('git', 'pull', 'origin', 'main').ordered
        expect(executor).to receive(:execute).with('git', 'merge', '--no-ff', '--message', "[gitx] Release feature-branch to main\n\nConnected to #10", 'feature-branch').ordered
        expect(executor).to receive(:execute).with('git', 'push', 'origin', 'HEAD').ordered
        expect(executor).to receive(:execute).with('git integrate --skip-pull-request').ordered

        stub_request(:post, 'https://api.github.com/repos/wireframe/gitx/pulls').to_return(status: 201, body: new_pull_request.to_json, headers: { 'Content-Type' => 'application/json' })
        VCR.use_cassette('pull_request_does_not_exist') do
          cli.release
        end
      end
      it 'creates pull request on github' do
        should meet_expectations
      end
      it 'runs expected commands' do
        should meet_expectations
      end
    end
    context 'when --cleanup flag passed' do
      let(:options) do
        {
          cleanup: true
        }
      end
      before do
        expect(repo).to receive(:workdir).and_return(temp_dir)

        expect(cli).to receive(:yes?).and_return(true)
        allow(cli).to receive(:authorization_token).and_return(authorization_token)

        expect(executor).to receive(:execute).with('git', 'checkout', 'feature-branch').ordered
        expect(executor).to receive(:execute).with('git', 'update').ordered
        expect(executor).to receive(:execute).with('git', 'checkout', 'main').ordered
        expect(executor).to receive(:execute).with('git', 'pull', 'origin', 'main').ordered
        expect(executor).to receive(:execute).with('git', 'merge', '--no-ff', '--message', "[gitx] Release feature-branch to main\n\nConnected to #10", 'feature-branch').ordered
        expect(executor).to receive(:execute).with('git', 'push', 'origin', 'HEAD').ordered
        expect(executor).to receive(:execute).with('git integrate --skip-pull-request').ordered
        expect(executor).to receive(:execute).with('git cleanup').ordered

        VCR.use_cassette('pull_request_does_exist_with_success_status') do
          cli.release
        end
      end
      it 'runs expected commands' do
        should meet_expectations
      end
    end
    context 'when user confirms release with release_label config' do
      let(:gitx_config) do
        {
          'release_label' => 'release-me'
        }
      end
      before do
        expect(repo).to receive(:workdir).and_return(temp_dir)
        File.open(File.join(temp_dir, '.gitx.yml'), 'w') do |f|
          f.puts gitx_config.to_yaml
        end

        expect(cli).to receive(:yes?).and_return(true)
        expect(cli).to receive(:label_pull_request).with(having_attributes(number: 10), 'release-me').and_call_original
        allow(cli).to receive(:authorization_token).and_return(authorization_token)

        expect(executor).to_not receive(:execute).with('git', 'checkout', 'main')
        expect(executor).to_not receive(:execute).with('git', 'pull', 'origin', 'main')
        expect(executor).to_not receive(:execute).with('git', 'merge', '--no-ff', '--message', "[gitx] Release feature-branch to main\n\nConnected to #10", 'feature-branch')
        expect(executor).to_not receive(:execute).with('git', 'push', 'origin', 'HEAD')

        expect(executor).to receive(:execute).with('git', 'checkout', 'feature-branch').ordered
        expect(executor).to receive(:execute).with('git', 'update').ordered
        expect(executor).to receive(:execute).with('git integrate --skip-pull-request').ordered

        VCR.use_cassette('pull_request_does_exist_and_then_add_label') do
          cli.release
        end
      end
      it 'runs expected commands' do
        should meet_expectations
      end
    end
    context 'when user confirms release with update_from_base_on_release config set to false' do
      let(:gitx_config) do
        {
          'update_from_base_on_release' => false
        }
      end
      before do
        expect(repo).to receive(:workdir).and_return(temp_dir)
        File.open(File.join(temp_dir, '.gitx.yml'), 'w') do |f|
          f.puts gitx_config.to_yaml
        end

        expect(cli).to receive(:yes?).and_return(true)
        expect(cli).to_not receive(:label_pull_request)
        expect(executor).to_not receive(:execute).with('git', 'update')
        allow(cli).to receive(:authorization_token).and_return(authorization_token)

        expect(executor).to receive(:execute).with('git', 'checkout', 'feature-branch').ordered
        expect(executor).to receive(:execute).with('git', 'checkout', 'main').ordered
        expect(executor).to receive(:execute).with('git', 'pull', 'origin', 'main').ordered
        expect(executor).to receive(:execute).with('git', 'merge', '--no-ff', '--message', "[gitx] Release feature-branch to main\n\nConnected to #10", 'feature-branch').ordered
        expect(executor).to receive(:execute).with('git', 'push', 'origin', 'HEAD').ordered
        expect(executor).to receive(:execute).with('git integrate --skip-pull-request').ordered

        VCR.use_cassette('pull_request_does_exist_with_success_status') do
          cli.release
        end
      end
      it 'runs expected commands' do
        should meet_expectations
      end
    end
  end
end
