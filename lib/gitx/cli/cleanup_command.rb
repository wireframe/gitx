require 'thor'
require 'gitx'
require 'gitx/cli/base_command'

module Gitx
  module Cli
    class CleanupCommand < BaseCommand
      desc 'cleanup', 'Cleanup branches that have been merged into master from the repo'
      def cleanup
        checkout_branch config.base_branch
        run_git_cmd 'pull'
        run_git_cmd 'remote', 'prune', 'origin'

        say 'Deleting local and remote branches that have been merged into '
        say config.base_branch, :green
        merged_branches(remote: true).each do |branch|
          run_git_cmd 'push', 'origin', '--delete', branch
        end
        merged_branches(remote: false).each do |branch|
          run_git_cmd 'branch', '--delete', branch
        end
      end

      private

      # @return list of branches that have been merged
      def merged_branches(options = {})
        args = []
        args << '--remote' if options[:remote]
        args << '--merged'
        output = run_git_cmd('branch', *args).split("\n")
        branches = output.map do |branch|
          branch = branch.gsub(/\*/, '').strip.split(' ').first
          branch = branch.gsub('origin/', '') if options[:remote]
          branch
        end
        branches.uniq!
        branches -= config.reserved_branches
        branches.reject! { |b| config.aggregate_branch?(b) }

        branches
      end
    end
  end
end
