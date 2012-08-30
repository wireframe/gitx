require "thor"
require 'rest_client'
require 'socialcast-git-extensions'
require 'socialcast-git-extensions/string_ext'
require 'socialcast-git-extensions/git'
require 'socialcast-git-extensions/github'

module Socialcast
  module Gitx
    class CLI < Thor
      include Socialcast::Git
      include Socialcast::Gitx::Github

      BASE_BRANCH = 'master'
      PULL_REQUEST_DESCRIPTION = "\n\n" + <<-EOS.dedent
        # Describe your pull request
        # Use GitHub flavored Markdown http://github.github.com/github-flavored-markdown/
        # Why not include a screenshot? Format is ![title](url)
      EOS

      method_option :quiet, :type => :boolean, :aliases => '-q'
      method_option :trace, :type => :boolean, :aliases => '-v'
      def initialize(*args)
        super(*args)
        RestClient.proxy = ENV['HTTPS_PROXY'] if ENV.has_key?('HTTPS_PROXY')
        RestClient.log = Logger.new(STDOUT) if options[:trace]
      end

      desc "reviewrequest", "Create a pull request on github"
      method_option :description, :type => :string, :aliases => '-d', :desc => 'pull request description'
      # @see http://developer.github.com/v3/pulls/
      def reviewrequest
        token = authorization_token

        invoke :update

        description = options[:description] || editor_input(PULL_REQUEST_DESCRIPTION)
        branch = current_branch
        repo = current_repo
        create_pull_request token, branch, repo, description

        short_description = description.split("\n").first(5).join("\n")
        review_message = ["@SocialcastDevelopers #reviewrequest for #{branch} #scgitx", short_description, changelog_summary(branch)].join("\n\n")
        share review_message, {:url => url, :message_type => 'review_request'}
      end

      desc 'update', 'Update the current branch with latest upstream changes'
      def update
        run_cmd 'git update'
      end

      private

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
      def editor_input(initial_text = '')
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

      # share message in socialcast
      # skip sharing message if CLI quiet option is present
      def share(message, params = {})
        return if options[:quiet]
        require 'socialcast'
        require 'socialcast/message'
        Socialcast::Message.configure_from_credentials
        Socialcast::Message.create params.merge(:body => message)
        say "Message has been shared"
      end
    end
  end
end
