require 'thor'
require 'gitx'
require 'gitx/cli/base_command'

module Gitx
  module Cli
    class BuildtagCommand < BaseCommand
      BUILD_TAG_PREFIX = 'builds'.freeze
      BUILD_TAG_SEPARATOR = '/'.freeze

      desc 'buildtag', 'create a tag for the current build and push it back to origin (supports Travis CI and Codeship)'
      method_option :branch, type: :string, aliases: '-b', desc: 'branch name for build tag'
      method_option :message, type: :string, aliases: '-m', desc: 'message to attach to the buildtag'
      def buildtag
        raise "Branch must be one of the supported taggable branches: #{config.taggable_branches}" unless config.taggable_branch?(branch_name)
        run_git_cmd 'tag', build_tag, '--annotate', '--message', label
        run_git_cmd 'push', 'origin', build_tag
      end

      private

      def branch_name
        options[:branch] || current_branch.name
      end

      def label
        options[:message] || "[gitx] buildtag for #{branch_name}"
      end

      def build_tag
        @buildtag ||= [
          BUILD_TAG_PREFIX,
          branch_name,
          utc_timestamp
        ].join(BUILD_TAG_SEPARATOR)
      end

      def utc_timestamp
        Time.now.utc.strftime '%Y-%m-%d-%H-%M-%S'
      end
    end
  end
end
