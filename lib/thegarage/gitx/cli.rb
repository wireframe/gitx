require 'English'
require "thor"
require 'rest_client'
require 'thegarage/gitx'
require 'thegarage/gitx/git'
require 'thegarage/gitx/runner'

module Thegarage
  module Gitx
    class CLI < Thor
      include Thor::Actions
      add_runtime_options!

      method_option :trace, :type => :boolean, :aliases => '-v'
      def initialize(*args)
        super(*args)
        RestClient.proxy = ENV['HTTPS_PROXY'] if ENV.has_key?('HTTPS_PROXY')
        RestClient.log = Logger.new(STDOUT) if options[:trace]
      end

      desc 'update', 'Update the current branch with latest changes from the remote feature branch and master'
      def update
        git.update
      end

      desc 'cleanup', 'Cleanup branches that have been merged into master from the repo'
      def cleanup
        git.cleanup
      end

      desc 'track', 'set the current branch to track the remote branch with the same name'
      def track
        git.track
      end

      desc 'start', 'start a new git branch with latest changes from master'
      def start(branch_name = nil)
        until git.valid_new_branch_name?(branch_name)
          example_branch = %w{ api-fix-invalid-auth desktop-cleanup-avatar-markup share-form-add-edit-link }.sample
          branch_name = ask("What would you like to name your branch? (ex: #{example_branch})")
        end

        git.start branch_name
      end

      desc 'share', 'Share the current branch in the remote repository'
      def share
        git.share
      end

      desc 'integrate', 'integrate the current branch into one of the aggregate development branches'
      def integrate(target_branch = 'staging')
        git.integrate target_branch
      end

      desc 'nuke', 'nuke the specified aggregate branch and reset it to a known good state'
      method_option :destination, :type => :string, :aliases => '-d', :desc => 'destination branch to reset to'
      def nuke(bad_branch)
        good_branch = options[:destination] || ask("What branch do you want to reset #{bad_branch} to? (default: #{bad_branch})")
        good_branch = bad_branch if good_branch.length == 0

        last_known_good_tag = git.current_build_tag(good_branch)
        return unless yes?("Reset #{bad_branch} to #{last_known_good_tag}? (y/n)", :green)

        git.nuke bad_branch, last_known_good_tag
      end

      desc 'release', 'release the current branch to production'
      def release
        return unless yes?("Release #{git.current_branch.name} to production? (y/n)", :green)
        git.release
      end

      desc 'buildtag', 'create a tag for the current Travis-CI build and push it back to origin'
      def buildtag
        git.buildtag
      end

      private

      def github
        @github ||= Thegarage::Gitx::Github.new(git.repo, shell)
      end

      def git
        @git ||= Thegarage::Gitx::Git.new(shell, runner)
      end

      def runner
        @runner ||= Thegarage::Gitx::Runner.new(shell, options)
      end
    end
  end
end
