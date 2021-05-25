require 'thor'
require 'gitx'
require 'gitx/cli/base_command'

module Gitx
  module Cli
    class UpdateCommand < BaseCommand
      desc 'update', 'Update the current branch with latest changes from the remote feature branch and main'
      def update
        say 'Updating '
        say "#{current_branch.name} ", :green
        say 'with latest changes from '
        say config.base_branch, :green

        update_branch(current_branch.name) if remote_branch_exists?(current_branch.name)
        update_branch(config.base_branch)
        update_base_branch

        run_git_cmd 'share'
      end

      private

      def update_base_branch
        branch_name = current_branch.name
        checkout_branch(config.base_branch)
        update_branch(config.base_branch)
        checkout_branch(branch_name)
      end

      def update_branch(branch)
        run_git_cmd 'pull', 'origin', branch
      rescue Gitx::Executor::ExecutionError
        raise MergeError, 'Merge conflict occurred. Please fix merge conflict and rerun the command'
      end

      def remote_branch_exists?(branch)
        repo.branches.each_name(:remote).include?("origin/#{branch}")
      end
    end
  end
end
