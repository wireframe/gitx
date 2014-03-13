require "thor"
require 'rest_client'
require 'thegarage/gitx'
require 'thegarage/gitx/github'

module Thegarage
  module Gitx
    class CLI < Thor
      include Thor::Actions
      add_runtime_options!

      include Thegarage::Gitx::Git

      TAGGABLE_BRANCHES = %w(master staging)

      method_option :trace, :type => :boolean, :aliases => '-v'
      def initialize(*args)
        super(*args)
        RestClient.proxy = ENV['HTTPS_PROXY'] if ENV.has_key?('HTTPS_PROXY')
        RestClient.log = Logger.new(STDOUT) if options[:trace]
      end

      desc "reviewrequest", "Create or update a pull request on github"
      method_option :description, :type => :string, :aliases => '-d', :desc => 'pull request description'
      method_option :assignee, :type => :string, :aliases => '-a', :desc => 'pull request assignee'
      method_option :open, :type => :boolean, :aliases => '-o', :desc => 'open the pull request in a web browser'
      # @see http://developer.github.com/v3/pulls/
      def reviewrequest
        update
        fail 'Github authorization token not found' unless github.authorization_token

        pull_request = github.find_pull_request(current_branch)
        if pull_request.nil?
          changelog = run_cmd "git log #{Thegarage::Gitx::BASE_BRANCH}...#{current_branch} --no-merges --pretty=format:'* %s%n%b'"
          pull_request = github.create_pull_request(current_branch, changelog, options)
          say 'Pull request created: '
          say pull_request['html_url'], :green
        end
        github.assign_pull_request(pull_request, options[:assignee]) if options[:assignee]

        run_cmd "open #{pull_request['html_url']}" if options[:open]
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
          example_branch = %w{ api-fix-invalid-auth desktop-cleanup-avatar-markup share-form-add-edit-link }.shuffle.first
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

        last_known_good_tag = build_tags_for_branch(good_branch).last
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

      desc 'buildtag', 'create a tag for the current Travis-CI build and push it back to origin'
      def buildtag
        branch = ENV['TRAVIS_BRANCH']
        pull_request = ENV['TRAVIS_PULL_REQUEST']

        raise "Unknown branch. ENV['TRAVIS_BRANCH'] is required." unless branch

        if pull_request != 'false'
          say "Skipping creation of tag for pull request: #{pull_request}"
        elsif !TAGGABLE_BRANCHES.include?(branch)
          say "Cannot create build tag for branch: #{branch}. Only #{TAGGABLE_BRANCHES} are supported."
        else
          label = "Generated tag from TravisCI build #{ENV['TRAVIS_BUILD_NUMBER']}"
          create_build_tag(branch, label)
        end
      end

      private

      # execute a shell command and raise an error if non-zero exit code is returned
      # return the string output from the command
      def run_cmd(cmd, options = {})
        output = run(cmd, capture: true)
        success = $CHILD_STATUS.to_i == 0
        fail "#{cmd} failed" unless success || options[:allow_failure]
        output
      end

      # check if --pretend or -p flag passed to CLI
      def pretend?
        options[:pretend]
      end

      def github
        @github ||= Thegarage::Gitx::Github.new(current_repo, self)
      end
    end
  end
end
