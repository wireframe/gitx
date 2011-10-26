require 'rest_client'
require 'json'

module Socialcast
  module Github
    def create_pull_request(username, password, branch, repo)
      payload = {:title => branch, :base => 'master', :head => branch}.to_json
      response = RestClient::Request.new(:url => "https://api.github.com/repos/#{repo}/pulls", :method => "POST", :user => username, :password => password, :payload => payload, :headers => {:accept => :json, :content_type => :json}).execute
      data = JSON.parse response.body
      url = data['html_url']
    end
  end
end
