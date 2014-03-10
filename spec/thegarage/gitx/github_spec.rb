require 'spec_helper'

describe Thegarage::Gitx::Github do
  let(:repo) { double('fake shell', config: repo_config) }
  let(:repo_config) do
    {
      'remote.origin.url' => 'https://github.com/thegarage/thegarage-gitx'
    }
  end
  let(:shell) { double('fake shell', say: nil, ask: nil) }
  subject { Thegarage::Gitx::Github.new(repo, shell) }

  describe '#create_pull_request' do
    context 'when github.user is not configured' do
      it 'raises error' do
        expect do
          subject.create_pull_request 'example-branch', 'changelog'
        end.to raise_error /Github user not configured/
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
         note: "The Garage Git eXtensions",
         note_url: "https://github.com/thegarage/thegarage-gitx"
        })
      end
      before do
        stub_request(:post, "https://ryan@codecrate.com:secretz@api.github.com/authorizations").
          with(:body => expected_auth_body).
          to_return(:status => 200, :body => JSON.dump(token: authorization_token), :headers => {})

        stub_request(:post, "https://api.github.com/repos/thegarage/thegarage-gitx/pulls").
          to_return(:status => 200, :body => %q({"html_url": "http://github.com/repo/project/pulls/1"}), :headers => {})

        expect(shell).to receive(:ask).with('Github password for ryan@codecrate.com: ', {:echo => false}).and_return(github_password).any_number_of_times

        expect(subject).to receive(:input_from_editor).and_return('scrubbed text')
        subject.create_pull_request 'example-branch', 'changelog'
      end
      it 'creates authorization_token' do
        expect(repo_config).to include('thegarage.gitx.githubauthtoken' => authorization_token)
      end
      it 'should create github pull request' do
        should meet_expectations
      end
      it 'should run expected commands' do
        should meet_expectations
      end
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
        stub_request(:post, "https://api.github.com/repos/thegarage/thegarage-gitx/pulls").
          to_return(:status => 200, :body => %q({"html_url": "http://github.com/repo/project/pulls/1"}), :headers => {})

        expect(subject).to receive(:input_from_editor).and_return('scrubbed text')
        subject.create_pull_request 'example-branch', 'changelog'
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
