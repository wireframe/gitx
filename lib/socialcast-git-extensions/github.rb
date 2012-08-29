require 'rest_client'
require 'json'
require 'socialcast'

module Socialcast
  module Github
    # @see http://developer.github.com/v3/oauth/#scopes
    def request_token
      credentials = Socialcast.credentials
      return credentials[:scgitx_token] if credentials[:scgitx_token]

      username = `git config -z --global --get github.user`.strip
      fail "Github user not configured.  Run: `git config --global github.user 'me@email.com'`" if username.empty?
      password = HighLine.ask("Github password for #{username}: ") { |q| q.echo = false }

      payload = {:scopes => ['repo'], :note => 'Socialcast Git eXtension', :note_url => 'https://github.com/socialcast/socialcast-git-extensions'}.to_json
      response = RestClient::Request.new(:url => "https://api.github.com/authorizations", :method => "POST", :user => username, :password => password, :payload => payload, :headers => {:accept => :json, :content_type => :json}).execute
      data = JSON.parse response.body
      token = data['token']
      Socialcast.credentials = credentials.merge(:scgitx_token => token)
      token
    rescue RestClient::Exception => e
      data = JSON.parse e.http_body
      HighLine.say "Failed to obtain OAuth token: #{data['message']}"
      false
    end

    # @see http://developer.github.com/v3/pulls/
    def create_pull_request(token, branch, repo, body)
      payload = {:title => branch, :base => 'master', :head => branch, :body => body}.to_json
      begin
        HighLine.say "Creating pull request for #{branch} against master in #{repo}"
        RestClient.proxy = ENV['HTTPS_PROXY'] if ENV.has_key?('HTTPS_PROXY')
        response = RestClient::Request.new(:url => "https://api.github.com/repos/#{repo}/pulls", :method => "POST", :payload => payload, :headers => {:accept => :json, :content_type => :json, 'Authorization' => "token #{token}"}).execute
        data = JSON.parse response.body
        url = data['html_url']
      rescue RestClient::Exception => e
        data = JSON.parse e.http_body
        HighLine.say "Failed to create pull request: #{data['message']}"
        false
      end
    end
  end
end
