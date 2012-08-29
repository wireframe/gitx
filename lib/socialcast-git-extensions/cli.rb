require "thor"
require 'rest_client'
require 'json'
require 'socialcast'
require 'socialcast-git-extensions'
require 'socialcast-git-extensions/git'

module Socialcast
  module Gitx
    class CLI < Thor
      include Socialcast::Git

      BASE_BRANCH = 'master'
      DEFAULT_PULL_REQUEST_DESCRIPTION = <<-EOS.dedent


        # Describe your pull request
        # Use GitHub flavored Markdown http://github.github.com/github-flavored-markdown/
        # Why not include a screenshot? Format is ![title](url)
      EOS

      desc "reviewrequest", "Create a pull request on github"
      method_option :description, :type => :string, :aliases => '-d', :desc => 'pull request description'
      # @see http://developer.github.com/v3/pulls/
      def reviewrequest
        token = authorization_token

        options[:description] ||= editor_input(DEFAULT_PULL_REQUEST_DESCRIPTION)

        invoke :update
        branch = current_branch
        repo = current_repo
        payload = {:title => branch, :base => BASE_BRANCH, :head => branch, :body => options[:description]}.to_json

        say "Creating pull request for #{branch} against #{BASE_BRANCH} in #{repo}"
        RestClient.proxy = ENV['HTTPS_PROXY'] if ENV.has_key?('HTTPS_PROXY')
        response = RestClient::Request.new(:url => "https://api.github.com/repos/#{repo}/pulls", :method => "POST", :payload => payload, :headers => {:accept => :json, :content_type => :json, 'Authorization' => "token #{token}"}).execute
        data = JSON.parse response.body
        url = data['html_url']

        short_description = description.split("\n").first(5).join("\n")
        review_message = ["@SocialcastDevelopers #reviewrequest for #{branch} #scgitx", short_description, changelog_summary(branch)].join("\n\n")
        share review_message, {:url => url, :message_type => 'review_request'}
      rescue RestClient::Exception => e
        data = JSON.parse e.http_body
        say "Failed to create pull request: #{data['message']}"
        throw e
      end

      # update the current branch with the latest upstream changes
      def update
        run_cmd 'git update'
      end

      private

      def current_repo
        repo = `git config -z --get remote.origin.url`.strip
        # ex: git@github.com:socialcast/socialcast-git-extensions.git
        repo.scan(/:(.+\/.+)\./).first.first
      end

      # build a summary of changes
      def changelog_summary(branch)
        changes = `git diff --stat origin/#{BASE_BRANCH}...#{branch}`.split("\n")
        stats = changes.pop
        if changes.length > 5
          dirs = changes.map do |file_change|
            filename = "#{file_change.split.first}"
            dir = filename.gsub(/\/[^\/]+$/, '')
            dir
          end
          dir_counts = Hash.new(0)
          dirs.each {|dir| dir_counts[dir] += 1 }
          changes = dir_counts.to_a.sort_by {|k,v| v}.reverse.first(5).map {|k,v| "#{k} (#{v} file#{'s' if v > 1})"}
        end
        (changes + [stats]).join("\n")
      end

      # launch configured editor to retreive message/string
      def editor_input(initial_text = ''
        require 'tempfile'
        Tempfile.open('reviewrequest.md') do |f|
          f << initial_text
          f.flush

          editor = ENV['EDITOR'] || 'vi'
          flags = case editor
          when 'mate', 'emacs'
            '-w'
          when 'mvim'
            '-f'
          else
            ''
          end
          pid = fork { exec "#{editor} #{flags} #{f.path}" }
          Process.waitpid(pid)
          description = File.read(f.path)
          description.gsub(/^\#.*/, '').chomp.strip
        end
      end

      # request github authorization token
      # store the token in ~/.socialcast/credentials.yml for future reuse
      # @see http://developer.github.com/v3/oauth/#scopes
      def authorization_token
        credentials = Socialcast.credentials
        return credentials[:scgitx_token] if credentials[:scgitx_token]

        username = `git config -z --global --get github.user`.strip
        raise "Github user not configured.  Run: `git config --global github.user 'me@email.com'`" if username.empty?
        password = ask("Github password for #{username}: ") { |q| q.echo = false }

        payload = {:scopes => ['repo'], :note => 'Socialcast Git eXtension', :note_url => 'https://github.com/socialcast/socialcast-git-extensions'}.to_json
        response = RestClient::Request.new(:url => "https://api.github.com/authorizations", :method => "POST", :user => username, :password => password, :payload => payload, :headers => {:accept => :json, :content_type => :json}).execute
        data = JSON.parse response.body
        token = data['token']
        Socialcast.credentials = credentials.merge(:scgitx_token => token)
        token
      rescue RestClient::Exception => e
        data = JSON.parse e.http_body
        say "Failed to obtain OAuth authorization token: #{data['message']}"
        throw e
      end
    end
  end
end
