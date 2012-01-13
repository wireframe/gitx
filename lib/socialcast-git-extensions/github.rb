require 'rest_client'
require 'json'

module Socialcast
  module Github
    def create_pull_request(username, password, branch, repo)
      payload = {:title => branch, :base => 'master', :head => branch}.to_json
      begin
        puts "Creating pull request for #{branch} against master in #{repo}"
        response = RestClient::Request.new(:url => "https://api.github.com/repos/#{repo}/pulls", :method => "POST", :user => username, :password => password, :payload => payload, :headers => {:accept => :json, :content_type => :json}).execute
        data = JSON.parse response.body
        url = data['html_url']
      rescue RestClient::Exception => e
        data = JSON.parse e.http_body
        puts "Failed to create pull request: #{data['message']}"
        false
      end
    end
  end
end

