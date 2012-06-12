require 'rest_client'
require 'json'

module Socialcast
  module Github
    # @see http://developer.github.com/v3/oauth/#scopes
    def request_token(username, password)
      payload = {:scopes => ['repo'], :note => 'Socialcast Git eXtension', :note_url => 'https://github.com/socialcast/socialcast-git-extensions'}.to_json
      response = RestClient::Request.new(:url => "https://api.github.com/authorizations", :method => "POST", :user => username, :password => password, :payload => payload, :headers => {:accept => :json, :content_type => :json}).execute
      data = JSON.parse response.body
      data['token']
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
        response = RestClient::Request.new(:url => "https://api.github.com/repos/#{repo}/pulls", :method => "POST", :payload => payload, :headers => {:accept => :json, :content_type => :json, 'Authorization' => "bearer #{token}"}).execute
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
