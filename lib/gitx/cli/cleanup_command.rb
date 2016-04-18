require 'thor'
require 'gitx'
require 'gitx/cli/base_command'

module Gitx
  module Cli
    class CleanupCommand < BaseCommand
      desc 'cleanup', 'Cleanup branches that have been merged into master from the repo'
      def cleanup
        update_base_branch
        say 'Deleting local and remote branches that have been merged into '
        say config.base_branch, :green
        filtered_merged_branches(:remote).each do |branch|
          run_git_cmd 'push', 'origin', '--delete', branch
        end
        filtered_merged_branches(:local).each do |branch|
          run_git_cmd 'branch', '--delete', branch
        end
      end

      private

      def update_base_branch
        checkout_branch config.base_branch
        run_git_cmd 'pull'
        run_git_cmd 'remote', 'prune', 'origin'
      end

      # @return list of branches that have been merged
      # filter out reserved and aggregate branches
      def filtered_merged_branches(source)
        merged_branches(source).reject do |branch|
          config.reserved_branches.include?(branch) || config.aggregate_branch?(b)
        end
      end

      # @return list of branches that have been merged
      # see http://stackoverflow.com/questions/26804024/git-branch-merged-sha-via-rugged-libgit2-bindings
      def merged_branches(source)
        merged_branches = repo.branches.each(source).select do |branch|
          target = branch.resolve.target
          repo.merge_base(base_branch_merge_target, target) == target.oid
        end
        merged_branches.map do |branch|
          branch.name.gsub('origin/', '')
        end
      end

      def base_branch_merge_target
        repo.head.target
      end
    end
  end
end
