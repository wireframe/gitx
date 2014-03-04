require 'thegarage/gitx/git'
require 'rest_client'
require 'json'

module Thegarage
  module Gitx
    module Github
      include Thegarage::Gitx::Git
      CLIENT_NAME = 'The Garage Git eXtensions'
      CLIENT_URL = 'https://github.com/thegarage/thegarage-gitx'

      private
      # request github authorization token
      # User-Agent is required
      # store the token in local git config
      # @see http://developer.github.com/v3/oauth/#scopes
      # @see http://developer.github.com/v3/#user-agent-required
      def authorization_token
        auth_token = github_auth_token
        return auth_token unless auth_token.to_s.blank?

        raise "Github user not configured.  Run: `git config --global github.user 'me@email.com'`" unless current_user
        password = ask("Github password for #{current_user}: ", :echo => false)

        payload = {
          :scopes => ['repo'],
          :note => CLIENT_NAME,
          :note_url => CLIENT_URL
        }.to_json
        response = RestClient::Request.new({
          :url => "https://api.github.com/authorizations",
          :method => "POST",
          :user => current_user,
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
        self.github_auth_token = token
        token
      rescue RestClient::Exception => e
        process_error e
        throw e
      end

      # returns the url of the created pull request
      # @see http://developer.github.com/v3/pulls/
      def create_pull_request(body, assignee = nil)
        branch = current_branch
        repo = current_remote_repo

        say "Creating pull request for "
        say "#{branch} ", :green
        say "against "
        say "#{Thegarage::Gitx::BASE_BRANCH} ", :green
        say "in "
        say repo, :green

        payload = {:title => branch, :base => Thegarage::Gitx::BASE_BRANCH, :head => branch, :body => body}.to_json
        response = RestClient::Request.new(:url => "https://api.github.com/repos/#{repo}/pulls", :method => "POST", :payload => payload, :headers => github_request_headers).execute
        data = JSON.parse response.body

        assign_pull_request(branch, assignee, data) if assignee

        url = data['html_url']
        url
      rescue RestClient::Exception => e
        process_error e
        throw e
      end

      def assign_pull_request(branch, assignee, data)
        issue_payload = { :title => branch, :assignee => assignee }.to_json
        RestClient::Request.new(:url => data['issue_url'], :method => "PATCH", :payload => issue_payload, :headers => github_request_headers).execute
      rescue RestClient::Exception => e
        process_error e
      end

      def process_error(e)
        data = JSON.parse e.http_body
        say "Github request failed: #{data['message']}", :red
      end

      def github_request_headers
        {
          :accept => :json,
          :content_type => :json,
          'Authorization' => "token #{authorization_token}"
        }
      end
    end
  end
end
