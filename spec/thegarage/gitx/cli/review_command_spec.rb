require 'spec_helper'
require 'thegarage/gitx/cli/review_command'

describe Thegarage::Gitx::Cli::ReviewCommand do
  let(:args) { [] }
  let(:options) { {} }
  let(:config) do
    {
      pretend: true
    }
  end
  let(:cli) { Thegarage::Gitx::Cli::ReviewCommand.new(args, options, config) }
  let(:repo) { double('fake repo', config: repo_config) }
  let(:repo_config) do
    {
      'remote.origin.url' => 'https://github.com/thegarage/thegarage-gitx'
    }
  end
  let(:branch) { double('fake branch', name: 'feature-branch') }

  before do
    allow(cli).to receive(:repo).and_return(repo)
    allow(cli).to receive(:current_branch).and_return(branch)
  end

  describe '#review' do
    let(:pull_request) do
      {
        'html_url' => 'https://path/to/new/pull/request',
        'issue_url' => 'https://api/path/to/new/pull/request',
        'head' => {
          'ref' => 'branch_name'
        }
      }
    end
    context 'when pull request does not exist' do
      let(:authorization_token) { '123123' }
      let(:changelog) { '* made some fixes' }
      let(:fake_update_command) { double('fake update command', update: nil) }
      before do
        expect(Thegarage::Gitx::Cli::UpdateCommand).to receive(:new).and_return(fake_update_command)

        expect(cli).to receive(:authorization_token).and_return(authorization_token)
        expect(cli).to receive(:find_pull_request).and_return(nil)
        expect(cli).to receive(:create_pull_request).and_return(pull_request)
        expect(cli).to receive(:run_cmd).with("git log master...feature-branch --no-merges --pretty=format:'* %s%n%b'").and_return("2013-01-01 did some stuff").ordered
        cli.review
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
        expect(cli).to receive(:authorization_token).and_return(authorization_token)
        expect { cli.review }.to raise_error(/token not found/)
      end
    end
    context 'when pull request already exists' do
      let(:authorization_token) { '123123' }
      before do
        expect(cli).to receive(:authorization_token).and_return(authorization_token)
        expect(cli).to receive(:find_pull_request).and_return(pull_request)
        expect(cli).to_not receive(:create_pull_request)

        cli.review
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
        expect(cli).to receive(:authorization_token).and_return(authorization_token).at_least(:once)
        expect(cli).to receive(:find_pull_request).and_return(pull_request)

        stub_request(:patch, 'https://api/path/to/new/pull/request').to_return(:status => 200)

        cli.review
      end
      it 'updates github pull request' do
        expect(WebMock).to have_requested(:patch, "https://api/path/to/new/pull/request").
          with(:body => {title: 'branch_name', assignee: 'johndoe'}.to_json,
               :headers => {'Accept'=>'application/json', 'Authorization'=>'token 123123', 'Content-Type'=>'application/json'})
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
        expect(cli).to receive(:authorization_token).and_return(authorization_token)
        expect(cli).to receive(:find_pull_request).and_return(pull_request)
        expect(cli).to receive(:run_cmd).with("open #{pull_request['html_url']}").ordered
        cli.review
      end
      it 'runs open command with pull request url' do
        should meet_expectations
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
    context 'when config.authorization_token is nil' do
      let(:repo_config) do
        {
          'remote.origin.url' => 'https://github.com/thegarage/thegarage-gitx',
          'github.user' => 'ryan@codecrate.com'
        }
      end
      let(:github_password) { 'secretz' }
      let(:authorization_token) { '123981239123' }
      let(:expected_auth_body) do
        JSON.dump({
         scopes: ["repo"],
         note: "The Garage Git eXtensions - thegarage/thegarage-gitx",
         note_url: "https://github.com/thegarage/thegarage-gitx"
        })
      end
      before do
        stub_request(:post, "https://ryan@codecrate.com:secretz@api.github.com/authorizations").
          with(:body => expected_auth_body).
          to_return(:status => 200, :body => JSON.dump(token: authorization_token), :headers => {})

        expect(cli).to receive(:ask).with('Github password for ryan@codecrate.com: ', {:echo => false}).and_return(github_password)

        @auth_token = cli.send(:authorization_token)
      end
      it 'stores authorization_token in git config' do
        expect(repo_config).to include('thegarage.gitx.githubauthtoken' => authorization_token)
      end
      it { expect(@auth_token).to eq authorization_token }
    end
    context 'when there is an existing authorization_token' do
      let(:authorization_token) { '123981239123' }
      let(:repo_config) do
        {
          'remote.origin.url' => 'https://github.com/thegarage/thegarage-gitx',
          'github.user' => 'ryan@codecrate.com',
          'thegarage.gitx.githubauthtoken' => authorization_token
        }
      end
      before do
        @auth_token = cli.send(:authorization_token)
      end
      it { expect(@auth_token).to eq authorization_token }
    end
  end
  describe '#create_pull_request' do
    context 'when there is an existing authorization_token' do
      let(:authorization_token) { '123981239123' }
      let(:repo_config) do
        {
          'remote.origin.url' => 'https://github.com/thegarage/thegarage-gitx',
          'github.user' => 'ryan@codecrate.com',
          'thegarage.gitx.githubauthtoken' => authorization_token
        }
      end
      before do
        stub_request(:post, "https://api.github.com/repos/thegarage/thegarage-gitx/pulls").
          to_return(:status => 200, :body => %q({"html_url": "http://github.com/repo/project/pulls/1"}), :headers => {})

        expect(cli).to receive(:input_from_editor).and_return('scrubbed text')
        cli.send(:create_pull_request, 'example-branch', 'changelog')
      end
      it 'should create github pull request' do
        should meet_expectations
      end
      it 'should run expected commands' do
        should meet_expectations
      end
    end
  end
end
