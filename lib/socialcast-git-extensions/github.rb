require 'rest_client'
require 'json'

module Socialcast
  module Github
    class << self
      def create_pull_request(username, password, branch)
        response = RestClient.post "https://#{username}:#{password}@api.github.com/repos/socialcast/socialcast/pulls", {:title => branch, :base => 'master', :head => branch}.to_json, :accept => :json, :content_type => :json
        data = JSON.parse response.body
        url = data['html_url']
      end
    end
  end
end
