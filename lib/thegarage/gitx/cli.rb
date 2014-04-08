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
