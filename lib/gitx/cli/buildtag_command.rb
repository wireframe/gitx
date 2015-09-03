require 'thor'
require 'gitx'
require 'gitx/cli/base_command'

module Gitx
  module Cli
    class BuildtagCommand < BaseCommand
      desc 'buildtag', 'create a tag for the current build and push it back to origin (supports Travis CI and Codeship)'
      method_option :branch, type: :string, aliases: '-b', desc: 'branch name for build tag'
      method_option :message, type: :string, aliases: '-m', desc: 'message to attach to the buildtag'
      def buildtag
        fail "Branch must be one of the supported taggable branches: #{config.taggable_branches}" unless config.taggable_branch?(branch_name)
        run_cmd "git tag #{git_tag} -a -m '#{label}'"
        run_cmd "git push origin #{git_tag}"
      end

      private

      def branch_name
        options[:branch] || current_branch.name
      end

      def label
        options[:message] || "[gitx] buildtag for #{branch_name}"
      end

      def git_tag
        timestamp = Time.now.utc.strftime '%Y-%m-%d-%H-%M-%S'
        "build-#{branch_name}-#{timestamp}"
      end
    end
  end
end
