require 'rest_client'
require 'json'
require 'tempfile'

module Thegarage
  module Gitx
    class Github
      CLIENT_NAME = 'The Garage Git eXtensions'
      CLIENT_URL = 'https://github.com/thegarage/thegarage-gitx'
      PULL_REQUEST_FOOTER = <<-EOS.dedent
        # Pull Request Protips(tm):
        # * Include description of how this change accomplishes the task at hand.
        # * Use GitHub flavored Markdown http://github.github.com/github-flavored-markdown/
        # * Review CONTRIBUTING.md for recommendations of artifacts, links, images, screencasts, etc.
        #
        # This footer will automatically be stripped from the pull request description
      EOS

      attr_reader :repo, :shell

      def initialize(repo, shell)
        @repo = repo
        @shell = shell
      end

      # returns [Hash] data structure of created pull request
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
      end

      # @see http://developer.github.com/v3/pulls/
      def create_pull_request(branch, changelog, options = {})
        body = pull_request_body(changelog, options[:description])

        shell.say "Creating pull request for "
        shell.say "#{branch} ", :green
        shell.say "against "
        shell.say "#{Thegarage::Gitx::BASE_BRANCH} ", :green
        shell.say "in "
        shell.say remote_origin_name, :green

        payload = {
          :title => branch,
          :base => Thegarage::Gitx::BASE_BRANCH,
          :head => branch,
          :body => body
        }.to_json
        response = RestClient::Request.new(:url => pull_request_url, :method => "POST", :payload => payload, :headers => request_headers).execute
        pull_request = JSON.parse response.body

        pull_request
      rescue RestClient::Exception => e
        process_error e
      end

      def assign_pull_request(pull_request, assignee)
        shell.say "Assigning pull request to "
        shell.say assignee, :green

        branch = pull_request['head']['ref']
        payload = {
          :title => branch,
          :assignee => assignee
        }.to_json
        RestClient::Request.new(:url => pull_request['issue_url'], :method => "PATCH", :payload => payload, :headers => request_headers).execute
      rescue RestClient::Exception => e
        process_error e
      end

      # @returns [Hash] data structure of pull request info if found
      # @returns nil if no pull request found
      def find_pull_request(branch)
        head_reference = [remote_origin_name.split('/').first, branch].join(':')
        params = {
          head: head_reference,
          state: 'open'
        }
        response = RestClient::Request.new(:url => pull_request_url, :method => "GET", :headers => request_headers.merge(params: params)).execute
        data = JSON.parse(response.body)
        data.first
      rescue RestClient::Exception => e
        process_error e
      end

      private

      def process_error(e)
        data = JSON.parse e.http_body
        shell.say "Github request failed: #{data['message']}", :red
        throw e
      end

      def pull_request_url
        "https://api.github.com/repos/#{remote_origin_name}/pulls"
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
        remote = repo.config['remote.origin.url']
        remote.to_s.gsub(/\.git$/,'').split(/[:\/]/).last(2).join('/')
      end

      def pull_request_body(changelog, description = nil)
        description_template = []
        description_template << "#{description}\n" if description
        description_template << '### Changelog'
        description_template << changelog
        description_template << PULL_REQUEST_FOOTER

        body = input_from_editor(description_template.join("\n"))
        body.gsub(PULL_REQUEST_FOOTER, '').chomp.strip
      end

      # launch configured editor to retreive message/string
      def input_from_editor(initial_text = '')
        Tempfile.open('reviewrequest.md') do |f|
          f << initial_text
          f.flush

          editor = repo.config['core.editor'] || ENV['EDITOR'] || 'vi'
          flags = case editor
          when 'mate', 'emacs', 'subl'
            '-w'
          when 'mvim'
            '-f'
          else
            ''
          end
          pid = fork { exec([editor, flags, f.path].join(' ')) }
          Process.waitpid(pid)
          File.read(f.path)
        end
      end
    end
  end
end
