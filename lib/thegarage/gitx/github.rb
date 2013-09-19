require 'thegarage/gitx/git'
require 'rest_client'
require 'json'

module Thegarage
  module Gitx
    module Github
      include Thegarage::Gitx::Git

      private
      # request github authorization token
      # User-Agent is required
      # store the token in ~/.socialcast/credentials.yml for future reuse
      # @see http://developer.github.com/v3/oauth/#scopes
      # @see http://developer.github.com/v3/#user-agent-required
      def authorization_token
        auth_token = github_auth_token
        return auth_token unless auth_token.blank?

        username = current_user
        raise "Github user not configured.  Run: `git config --global github.user 'me@email.com'`" if username.empty?
        password = ask("Github password for #{username}: ") { |q| q.echo = false }

        payload = {:scopes => ['repo'], :note => 'Socialcast Git eXtension', :note_url => 'https://github.com/socialcast/thegarage/gitx'}.to_json
        response = RestClient::Request.new(:url => "https://api.github.com/authorizations", :method => "POST", :user => username, :password => password, :payload => payload, :headers => {:accept => :json, :content_type => :json, :user_agent => 'thegarage/gitx'}).execute
        data = JSON.parse response.body
        token = data['token']
        github_auth_token = token
        token
      rescue RestClient::Exception => e
        process_error e
        throw e
      end

      # returns the url of the created pull request
      # @see http://developer.github.com/v3/pulls/
      def create_pull_request(token, branch, repo, body)
        payload = {:title => branch, :base => Thegarage::Gitx::BASE_BRANCH, :head => branch, :body => body}.to_json
        say "Creating pull request for "
        say "#{branch} ", :green
        say "against "
        say "#{Thegarage::Gitx::BASE_BRANCH} ", :green
        say "in "
        say repo, :green
        response = RestClient::Request.new(:url => "https://api.github.com/repos/#{repo}/pulls", :method => "POST", :payload => payload, :headers => {:accept => :json, :content_type => :json, 'Authorization' => "token #{token}"}).execute
        data = JSON.parse response.body
        url = data['html_url']
        url
      rescue RestClient::Exception => e
        process_error e
        throw e
      end

      def process_error(e)
        data = JSON.parse e.http_body
        say "Failed to create pull request: #{data['message']}", :red
      end
    end
  end
end
