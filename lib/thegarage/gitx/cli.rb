require "thor"
require 'rest_client'
require 'thegarage/gitx'

module Thegarage
  module Gitx
    class CLI < Thor
      include Thegarage::Gitx
      include Thegarage::Gitx::Git
      include Thegarage::Gitx::Github

      PULL_REQUEST_DESCRIPTION = "\n\n" + <<-EOS.dedent
        # Use GitHub flavored Markdown http://github.github.com/github-flavored-markdown/
        # Links to screencasts or screenshots with a desciption of what this is showcasing. For architectual changes please include diagrams that will make it easier for the reviewer to understand the change. Format is ![title](url).
        # Link to ticket describing feature/bug (plantain, JIRA, bugzilla). Format is [title](url).
        # Brief description of the change, and how it accomplishes the task they set out to do.
      EOS

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
        update

        token = authorization_token
        description = options[:description] || editor_input(PULL_REQUEST_DESCRIPTION)
        branch = current_branch
        repo = current_remote_repo
        url = create_pull_request token, branch, repo, description
        say "Pull request created: #{url}"
      end

      # TODO: use --no-edit to skip merge messages
      # TODO: use pull --rebase to skip merge commit
      desc 'update', 'Update the current branch with latest changes from the remote feature branch and master'
      def update
        branch = current_branch

        say 'updating '
        say "#{branch} ", :green
        say "to have most recent changes from "
        say Thegarage::Gitx::BASE_BRANCH, :green

        run_cmd "git pull origin #{branch}", :allow_failure => true
        run_cmd "git pull origin #{Thegarage::Gitx::BASE_BRANCH}"
        run_cmd 'git push origin HEAD'
      end

      desc 'cleanup', 'Cleanup branches that have been merged into master from the repo'
      def cleanup
        run_cmd "git checkout #{Thegarage::Gitx::BASE_BRANCH}"
        run_cmd "git pull"
        run_cmd 'git remote prune origin'

        say "Deleting branches that have been merged into "
        say Thegarage::Gitx::BASE_BRANCH, :green
        branches(:merged => true, :remote => true).each do |branch|
          run_cmd "git push origin --delete #{branch}" unless aggregate_branch?(branch)
        end
        branches(:merged => true).each do |branch|
          run_cmd "git branch -d #{branch}" unless aggregate_branch?(branch)
        end
      end

      desc 'track', 'set the current branch to track the remote branch with the same name'
      def track
        track_branch current_branch
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

        run_cmd "git checkout #{Thegarage::Gitx::BASE_BRANCH}"
        run_cmd 'git pull'
        run_cmd "git checkout -b #{branch_name}"
      end

      desc 'share', 'Share the current branch in the remote repository'
      def share
        share_branch current_branch
      end

      desc 'integrate', 'integrate the current branch into one of the aggregate development branches'
      def integrate(target_branch = 'staging')
        branch = current_branch

        update
        integrate_branch(branch, target_branch)
        run_cmd "git checkout #{branch}"
      end

      desc 'nuke', 'nuke the specified aggregate branch and reset it to a known good state'
      method_option :destination, :type => :string, :aliases => '-d', :desc => 'destination branch to reset to'
      def nuke(bad_branch)
        good_branch = options[:destination] || ask("What branch do you want to reset #{bad_branch} to? (default: #{bad_branch})")
        good_branch = bad_branch if good_branch.length == 0

        run_cmd "git fetch --tags"
        good_tags = run_cmd("git tag -l 'build-#{good_branch}-*'").split
        last_known_good_tag = good_tags.sort.last
        raise "No known good tag found for branch: #{good_branch}.  Verify tag exists via `git tag -l 'build-#{good_branch}-*'`" unless last_known_good_tag
        return unless yes?("Reset #{bad_branch} to #{last_known_good_tag}? (y/n)", :green)

        nuke_branch(bad_branch, last_known_good_tag)
      end

      desc 'release', 'release the current branch to production'
      def release
        branch = current_branch
        assert_not_protected_branch!(branch, 'release')
        update

        return unless yes?("Release #{branch} to production? (y/n)", :green)
        run_cmd "git checkout #{Thegarage::Gitx::BASE_BRANCH}"
        run_cmd "git pull origin #{Thegarage::Gitx::BASE_BRANCH}"
        run_cmd "git pull . #{branch}"
        run_cmd "git push origin HEAD"
        integrate_branch('master', 'staging')
        cleanup
      end
    end
  end
end
