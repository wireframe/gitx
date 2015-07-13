require 'spec_helper'
require 'gitx/cli/review_command'

describe Gitx::Cli::ReviewCommand do
  let(:args) { [] }
  let(:options) { {} }
  let(:config) do
    {
      pretend: true
    }
  end
  let(:cli) { described_class.new(args, options, config) }
  let(:repo) { double('fake repo', config: repo_config) }
  let(:repo_config) do
    {
      'remote.origin.url' => 'https://github.com/wireframe/gitx'
    }
  end
  let(:branch) { double('fake branch', name: 'feature-branch') }

  before do
    allow(cli).to receive(:repo).and_return(repo)
    allow(cli).to receive(:current_branch).and_return(branch)
    allow(cli).to receive(:ask_editor).and_return('description')
  end

  describe '#review' do
    context 'when pull request does not exist' do
      let(:authorization_token) { '123123' }
      let(:changelog) { '* made some fixes' }
      let(:fake_update_command) { double('fake update command', update: nil) }
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
      let(:changelog) { "* old commit\n\n* new commit" }
      before do
        expect(Gitx::Cli::UpdateCommand).to receive(:new).and_return(fake_update_command)

        allow(cli).to receive(:authorization_token).and_return(authorization_token)
        expect(cli).to receive(:run_cmd).with('git checkout feature-branch').ordered
        expect(cli).to receive(:run_cmd).with("git log master...feature-branch --reverse --no-merges --pretty=format:'* %B'").and_return(changelog).ordered
        expect(cli).to receive(:ask_editor).with("### What changed?\n#{changelog}\n### What was fixed?\n\n### What else needs to be done?", hash_including(footer: Gitx::Github::PULL_REQUEST_FOOTER)).and_return('description')

        stub_request(:post, 'https://api.github.com/repos/wireframe/gitx/pulls').to_return(status: 201, body: new_pull_request.to_json, headers: { 'Content-Type' => 'application/json' })

        VCR.use_cassette('pull_request_does_not_exist') do
          cli.review
        end
      end
      it 'creates github pull request' do
        should meet_expectations
      end
      it 'runs expected commands' do
        should meet_expectations
      end
    end
    context 'when target branch is not nil and pull request does not exist' do
      let(:authorization_token) { '123123' }
      let(:changelog) { '* made some fixes' }
      let(:fake_update_command) { double('fake update command', update: nil) }
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
      let(:changelog) { "* old commit\n\n* new commit" }
      before do
        expect(Gitx::Cli::UpdateCommand).to receive(:new).and_return(fake_update_command)

        allow(cli).to receive(:authorization_token).and_return(authorization_token)
        expect(cli).to receive(:run_cmd).with('git checkout feature-branch').ordered
        expect(cli).to receive(:run_cmd).with("git log master...feature-branch --reverse --no-merges --pretty=format:'* %B'").and_return(changelog).ordered
        expect(cli).to receive(:ask_editor).with("### What changed?\n#{changelog}\n### What was fixed?\n\n### What else needs to be done?", hash_including(footer: Gitx::Github::PULL_REQUEST_FOOTER)).and_return('description')

        stub_request(:post, 'https://api.github.com/repos/wireframe/gitx/pulls').to_return(status: 201, body: new_pull_request.to_json, headers: { 'Content-Type' => 'application/json' })

        VCR.use_cassette('pull_request_does_not_exist') do
          cli.review 'feature-branch'
        end
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
        allow(cli).to receive(:authorization_token).and_return(authorization_token)
        expect { cli.review }.to raise_error(/token not found/)
      end
    end
    context 'when pull request already exists' do
      let(:authorization_token) { '123123' }
      before do
        allow(cli).to receive(:authorization_token).and_return(authorization_token)
        expect(cli).to_not receive(:create_pull_request)

        VCR.use_cassette('pull_request_does_exist_with_success_status') do
          cli.review
        end
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
        allow(cli).to receive(:authorization_token).and_return(authorization_token)

        stub_request(:patch, /.*api.github.com.*/).to_return(status: 200)

        VCR.use_cassette('pull_request_does_exist_with_success_status') do
          cli.review
        end
      end
      it 'updates github pull request' do
        expect(WebMock).to have_requested(:patch, 'https://api.github.com/repos/wireframe/gitx/issues/10')
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
        allow(cli).to receive(:authorization_token).and_return(authorization_token)
        expect(cli).to receive(:run_cmd).with('open https://path/to/html/pull/request').ordered
        VCR.use_cassette('pull_request_does_exist_with_success_status') do
          cli.review
        end
      end
      it 'runs open command with pull request url' do
        should meet_expectations
      end
    end
    context 'when --bump flag is passed' do
      let(:options) do
        {
          bump: true
        }
      end
      let(:authorization_token) { '123123' }
      let(:reference) { double('fake reference', target_id: 'e12da4') }
      before do
        allow(cli).to receive(:authorization_token).and_return(authorization_token)
        expect(cli).to receive(:ask_editor).and_return('comment description')
        allow(repo).to receive(:head).and_return(reference)
        stub_request(:post, /.*api.github.com.*/).to_return(status: 201)

        VCR.use_cassette('pull_request_does_exist_with_success_status') do
          cli.review
        end
      end
      it 'posts comment to github' do
        expect(WebMock).to have_requested(:post, 'https://api.github.com/repos/wireframe/gitx/issues/10/comments')
          .with(body: { body: "[gitx] review bump :tada:\n\ncomment description" })
      end
      it 'creates pending build status for latest commit' do
        expect(WebMock).to have_requested(:post, 'https://api.github.com/repos/wireframe/gitx/statuses/e12da4')
          .with(body: { state: 'pending', context: 'peer_review', description: 'Peer review in progress' })
      end
    end
    context 'when --reject flag is passed' do
      let(:options) do
        {
          reject: true
        }
      end
      let(:authorization_token) { '123123' }
      let(:reference) { double('fake reference', target_id: 'e12da4') }
      before do
        allow(cli).to receive(:authorization_token).and_return(authorization_token)
        expect(cli).to receive(:ask_editor).and_return('comment body')
        allow(repo).to receive(:head).and_return(reference)
        stub_request(:post, /.*api.github.com.*/).to_return(status: 201)

        VCR.use_cassette('pull_request_does_exist_with_success_status') do
          cli.review
        end
      end
      it 'posts comment to github' do
        expect(WebMock).to have_requested(:post, 'https://api.github.com/repos/wireframe/gitx/issues/10/comments')
          .with(body: { body: "[gitx] review rejected\n\ncomment body" })
      end
      it 'creates failure build status for latest commit' do
        expect(WebMock).to have_requested(:post, 'https://api.github.com/repos/wireframe/gitx/statuses/e12da4')
          .with(body: { state: 'failure', context: 'peer_review', description: 'Peer review rejected' })
      end
    end
    context 'when --approve flag is passed' do
      let(:options) do
        {
          approve: true
        }
      end
      let(:authorization_token) { '123123' }
      let(:reference) { double('fake reference', target_id: 'e12da4') }
      before do
        allow(cli).to receive(:authorization_token).and_return(authorization_token)
        expect(cli).to receive(:ask_editor).and_return('comment body')
        allow(repo).to receive(:head).and_return(reference)
        stub_request(:post, /.*api.github.com.*/).to_return(status: 201)

        VCR.use_cassette('pull_request_does_exist_with_success_status') do
          cli.review
        end
      end
      it 'posts comment to github' do
        expect(WebMock).to have_requested(:post, 'https://api.github.com/repos/wireframe/gitx/issues/10/comments')
          .with(body: { body: "[gitx] review approved :shipit:\n\ncomment body" })
      end
      it 'creates success build status for latest commit' do
        expect(WebMock).to have_requested(:post, 'https://api.github.com/repos/wireframe/gitx/statuses/e12da4')
          .with(body: { state: 'success', context: 'peer_review', description: 'Peer review approved' })
      end
    end
  end

  describe '#authorization_token' do
    context 'when github.user is not configured' do
      it 'raises error' do
        expect do
          cli.send(:authorization_token)
        end.to raise_error(/Github user not configured/)
      end
    end
    context 'when ENV[GITX_GITHUB_TOKEN] is set' do
      let(:auth_token) { '123123' }
      before do
        ENV['GITX_GITHUB_TOKEN'] = auth_token
        expect(cli).to_not receive(:ask)
        @auth_token = cli.send(:authorization_token)
      end
      after do
        ENV.delete('GITX_GITHUB_TOKEN')
      end
      it { expect(@auth_token).to eq auth_token }
      it { is_expected.to meet_expectations }
    end
    context 'when global config token is nil' do
      let(:repo_config) do
        {
          'remote.origin.url' => 'https://github.com/wireframe/gitx',
          'github.user' => 'ryan@codecrate.com'
        }
      end
      let(:github_password) { 'secretz' }
      let(:authorization_token) { '123981239123' }
      before do
        stub_request(:post, 'https://ryan@codecrate.com:secretz@api.github.com/authorizations')
          .to_return(status: 200, body: JSON.dump(token: authorization_token), headers: { 'Content-Type' => 'application/json' })

        expect(cli).to receive(:ask).with('Github password for ryan@codecrate.com: ', echo: false).and_return(github_password)
        expect(cli).to receive(:ask).with('Github two factor authorization token (if enabled): ', echo: false).and_return(nil)

        @auth_token = cli.send(:authorization_token)
      end
      it 'stores authorization_token in global config' do
        expect(global_config).to include('token' => authorization_token)
      end
      it { expect(@auth_token).to eq authorization_token }
    end
    context 'when global authorization_token is nil and first request fails' do
      let(:repo_config) do
        {
          'remote.origin.url' => 'https://github.com/wireframe/gitx',
          'github.user' => 'ryan@codecrate.com'
        }
      end
      let(:github_password) { 'secretz' }
      let(:authorization_token) { '123981239123' }
      before do
        stub_request(:post, 'https://ryan@codecrate.com:secretz@api.github.com/authorizations')
          .to_return(status: 401, body: JSON.dump(token: authorization_token), headers: { 'Content-Type' => 'application/json' })
          .then
          .to_return(status: 200, body: JSON.dump(token: authorization_token), headers: { 'Content-Type' => 'application/json' })

        expect(cli).to receive(:ask).with('Github password for ryan@codecrate.com: ', echo: false).and_return(github_password).twice
        expect(cli).to receive(:ask).with('Github two factor authorization token (if enabled): ', echo: false).and_return(nil).twice

        @auth_token = cli.send(:authorization_token)
      end
      it 'stores authorization_token in global config' do
        expect(global_config).to include('token' => authorization_token)
      end
      it { expect(@auth_token).to eq authorization_token }
    end
    context 'when the global config has an existing token' do
      let(:authorization_token) { '123981239123' }
      let(:repo_config) do
        {
          'remote.origin.url' => 'https://github.com/wireframe/gitx',
          'github.user' => 'ryan@codecrate.com'
        }
      end
      let(:config) do
        {
          'token' => authorization_token
        }
      end
      before do
        File.open(global_config_file, 'w') do |file|
          file.write(config.to_yaml)
        end
        @auth_token = cli.send(:authorization_token)
      end
      it { expect(@auth_token).to eq authorization_token }
    end
    context 'when two factor authorization token given' do
      let(:repo_config) do
        {
          'remote.origin.url' => 'https://github.com/wireframe/gitx',
          'github.user' => 'ryan@codecrate.com'
        }
      end
      let(:github_password) { 'secretz' }
      let(:authorization_token) { '123981239123' }
      let(:two_factor_auth_token) { '456456' }
      before do
        stub_request(:post, 'https://ryan@codecrate.com:secretz@api.github.com/authorizations')
          .with(headers: { 'X-GitHub-OTP' => two_factor_auth_token })
          .to_return(status: 200, body: JSON.dump(token: authorization_token), headers: { 'Content-Type' => 'application/json' })

        expect(cli).to receive(:ask).with('Github password for ryan@codecrate.com: ', echo: false).and_return(github_password)
        expect(cli).to receive(:ask).with('Github two factor authorization token (if enabled): ', echo: false).and_return(two_factor_auth_token)

        @auth_token = cli.send(:authorization_token)
      end
      it 'stores authorization_token in global config' do
        expect(global_config).to include('token' => authorization_token)
      end
      it { expect(@auth_token).to eq authorization_token }
    end
  end
end
