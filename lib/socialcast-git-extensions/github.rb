require 'rest_client'
require 'json'
require 'socialcast'

module Socialcast
  module Gitx
    module Github
      private
      # request github authorization token
      # User-Agent is required
      # store the token in ~/.socialcast/credentials.yml for future reuse
      # @see http://developer.github.com/v3/oauth/#scopes
      # @see http://developer.github.com/v3/#user-agent-required
      def authorization_token
        credentials = Socialcast.credentials
        return credentials[:scgitx_token] if credentials[:scgitx_token]

        username = current_user
        raise "Github user not configured.  Run: `git config --global github.user 'me@email.com'`" if username.empty?
        password = ask("Github password for #{username}: ") { |q| q.echo = false }

        payload = {:scopes => ['repo'], :note => 'Socialcast Git eXtension', :note_url => 'https://github.com/socialcast/socialcast-git-extensions'}.to_json
        response = RestClient::Request.new(:url => "https://api.github.com/authorizations", :method => "POST", :user => username, :password => password, :payload => payload, :headers => {:accept => :json, :content_type => :json, :user_agent => 'socialcast-git-extensions'}).execute
        data = JSON.parse response.body
        token = data['token']
        Socialcast.credentials = credentials.merge(:scgitx_token => token)
        token
      rescue RestClient::Exception => e
        process_error e
        throw e
      end

      # returns the url of the created pull request
      # @see http://developer.github.com/v3/pulls/
      def create_pull_request(token, branch, repo, body)
        payload = {:title => branch, :base => Socialcast::Gitx::BASE_BRANCH, :head => branch, :body => body}.to_json
        say "Creating pull request for "
        say "#{branch} ", :green
        say "against "
        say "#{Socialcast::Gitx::BASE_BRANCH} ", :green
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
      
      # @returns [String] socialcast username to assign the review to
      # @returns [nil] when no buddy system configured or user not found
      def socialcast_review_buddy(current_user)
        review_requestor = review_buddies[current_user]
        
        if review_requestor && review_buddies[review_requestor['buddy']]
          review_buddies[review_requestor['buddy']]['socialcast_username']
        end
      end
    end
  end
end
