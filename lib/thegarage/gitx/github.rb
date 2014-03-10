require 'rest_client'
require 'json'

module Thegarage
  module Gitx
    class Github
      CLIENT_NAME = 'The Garage Git eXtensions'
      CLIENT_URL = 'https://github.com/thegarage/thegarage-gitx'

      attr_reader :repo, :shell

      def initialize(repo, shell)
        @repo = repo
        @shell = shell
      end

      # request github authorization token
      # User-Agent is required
      # store the token in local git config
      # @returns [String] auth token stored in git (current repo, user config or installed global settings)
      # @see http://developer.github.com/v3/oauth/#scopes
      # @see http://developer.github.com/v3/#user-agent-required
      def authorization_token
        auth_token = repo.config['thegarage.gitx.githubauthtoken']
        return auth_token unless auth_token.to_s.blank?

        fail "Github user not configured.  Run: `git config --global github.user 'me@email.com'`" unless username
        password = shell.ask("Github password for #{username}: ", :echo => false)

        shell.say "Creating pull request for "
        shell.say "#{branch} ", :green
        shell.say "against "
        shell.say "#{Thegarage::Gitx::BASE_BRANCH} ", :green
        shell.say "in "
        shell.say repo, :green

        payload = {
          :scopes => ['repo'],
          :note => CLIENT_NAME,
          :note_url => CLIENT_URL
        }.to_json
        response = RestClient::Request.new({
          :url => "https://api.github.com/authorizations",
          :method => "POST",
          :user => username,
          :password => password,
          :payload => payload,
          :headers => {
            :accept => :json,
            :content_type => :json,
            :user_agent => 'thegarage/gitx'
          }
        }).execute
        data = JSON.parse response.body
        token = data['token']
        repo.config['thegarage.gitx.githubauthtoken'] = token
        token
      rescue RestClient::Exception => e
        process_error e
        throw e
      end

      # returns the url of the created pull request
      # @see http://developer.github.com/v3/pulls/
      def create_pull_request(branch, body, assignee = nil)
        repo = remote_origin_name
        payload = {:title => branch, :base => Thegarage::Gitx::BASE_BRANCH, :head => branch, :body => body}.to_json
        response = RestClient::Request.new(:url => "https://api.github.com/repos/#{repo}/pulls", :method => "POST", :payload => payload, :headers => request_headers).execute
        data = JSON.parse response.body

        assign_pull_request(branch, assignee, data) if assignee

        url = data['html_url']
        url
      rescue RestClient::Exception => e
        process_error e
        throw e
      end

      private

      def assign_pull_request(branch, assignee, data)
        issue_payload = { :title => branch, :assignee => assignee }.to_json
        RestClient::Request.new(:url => data['issue_url'], :method => "PATCH", :payload => issue_payload, :headers => request_headers).execute
      rescue RestClient::Exception => e
        process_error e
      end

      def process_error(e)
        data = JSON.parse e.http_body
        shell.say "Github request failed: #{data['message']}", :red
      end

      def request_headers
        {
          :accept => :json,
          :content_type => :json,
          'Authorization' => "token #{authorization_token}"
        }
      end

      # @returns [String] github username (ex: 'wireframe') of the current github.user
      # @returns empty [String] when no github.user is set on the system
      def username
        repo.config['github.user']
      end

      # lookup the current repository of the PWD
      # ex: git@github.com:socialcast/thegarage/gitx.git OR https://github.com/socialcast/thegarage/gitx.git
      def remote_origin_name
        repo = repo.config['remote.origin.url']
        repo.to_s.gsub(/\.git$/,'').split(/[:\/]/).last(2).join('/')
      end
    end
  end
end
