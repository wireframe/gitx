require "thor"
require 'rest_client'
require 'socialcast-git-extensions'

module Socialcast
  module Gitx
    class CLI < Thor
      include Socialcast::Gitx
      include Socialcast::Gitx::Git
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
        branch = current_branch

        say "updating <%= color('#{branch}', :green) %> to have most recent changes from <%= color('#{BASE_BRANCH}', :green) %>"
        run_cmd "git pull origin #{branch}" rescue nil
        run_cmd "git pull origin #{BASE_BRANCH}"
        run_cmd 'git push origin HEAD'
        run_cmd 'git remote prune origin'
      end

      desc 'prunemerged', 'Prune branches that have been merged into master from the repo'
      method_option :remote, :type => :boolean, :aliases => '-r'
      def prunemerged
        run_cmd "git checkout #{BASE_BRANCH}"
        run_cmd "git pull"

        say "Deleting <%= color('#{remote ? 'remote' : 'local'}', :green) %> branches that have been merged into <%= color('#{BASE_BRANCH}', :green) %>"
        branches(:merged => true).each do |branch|
          run_cmd "git branch -d #{branch}"
        end
        if options[:remote]
          branches(:merged => true, :remote => true).each do |branch|
            run_cmd "grb rm #{branch}"
          end
        end
      end

      desc 'track', 'set the current branch to track the remote branch with the same name'
      def track
        branch = current_branch
        run_cmd "git branch --set-upstream #{branch} origin/#{branch}"
      end

      desc 'start', 'start a new git branch with latest changes from master'
      def start(branch_name = nil)
        unless branch_name
          example_branch = %w{ api-fix-invalid-auth desktop-cleanup-avatar-markup share-form-add-edit-link }.sort_by { rand }.first
          repo = Grit::Repo.new(Dir.pwd)
          remote_branches = repo.remotes.collect {|b| b.name.split('/').last }
          until branch_name = ask("What would you like to name your branch? (ex: #{example_branch})") {|q|
              q.validate = Proc.new { |branch|
                branch =~ /^[A-Za-z0-9\-_]+$/ && !remote_branches.include?(branch)
              }
            }
          end
        end

        run_cmd "git checkout #{BASE_BRANCH}"
        run_cmd 'git pull'
        run_cmd "git checkout -b #{branch_name}"

        share "#worklog starting work on #{branch_name} #scgitx"
      end

      desc 'share', 'publish the current branch for peer review'
      def share
        run_cmd "grb publish #{current_branch}"
      end

      desc 'integrate', 'integrate the current branch into one of the aggregate development branches'
      def integrate(target_branch)
        branch = current_branch

        run_cmd 'git update'
        integrate(branch, target_branch)
        integrate(branch, 'prototype') if target_branch == 'staging'

        share "#worklog integrating #{branch} into #{target_branch} #scgitx"
      end

      desc 'nuke', 'nuke the current remote branch and reset it to a known good state'
      def nuke(branch, head_branch = 'last_known_good_master')
        removed_branches = reset_branch(branch, head_branch)
        reset_branch("last_known_good_#{branch}", head_branch)

        share "#worklog resetting #{branch} branch to #{head_branch} #scgitx\n\nthe following branches were affected:\n#{removed_branches.map{|b| '* ' + b}.join("\n") }" if options[:share]
      end

      desc 'release', 'release the current branch to production'
      def release
        branch = current_branch
        assert_not_protected_branch!(branch, 'release')

        return unless agree("<%= color('Release #{branch} to production? (y/n)', :green) %>")

        run_cmd 'git update'
        integrate branch, 'master'
        integrate branch, 'staging'
        run_cmd "git checkout master"
        run_cmd "grb rm #{branch}"

        share "#worklog releasing #{branch} to production #scgitx"
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
