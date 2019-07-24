require 'thor'
require 'gitx'
require 'gitx/cli/base_command'
require 'gitx/cli/update_command'
require 'gitx/github'

module Gitx
  module Cli
    class IntegrateCommand < BaseCommand
      include Gitx::Github
      desc 'integrate', 'integrate the current branch into one of the aggregate development branches (default = staging)'
      method_option :resume, type: :string, aliases: '-r', desc: 'resume merging of feature-branch'
      def integrate(integration_branch = 'staging')
        assert_aggregate_branch!(integration_branch)

        branch = feature_branch_name
        print_message(branch, integration_branch)

        run_git_cmd 'update'
        pull_request = pull_request_for_branch(branch)
        integrate_branch(branch, integration_branch, pull_request) unless options[:resume]
        checkout_branch branch
      end

      private

      def print_message(branch, integration_branch)
        message = options[:resume] ? 'Resuming integration of' : 'Integrating'
        say "#{message} "
        say "#{branch} ", :green
        say 'into '
        say integration_branch, :green
      end

      def pull_request_for_branch(branch)
        return nil if config.reserved_branch?(branch)

        find_or_create_pull_request(branch)
      end

      def integrate_branch(branch, integration_branch, pull_request)
        fetch_remote_branch(integration_branch)
        begin
          run_git_cmd 'merge', '--no-ff', '--message', commit_message(branch, integration_branch, pull_request), branch
        rescue Gitx::Executor::ExecutionError
          raise MergeError, "Merge conflict occurred.  Please fix merge conflict and rerun command with --resume #{branch} flag"
        end
        run_git_cmd 'push', 'origin', 'HEAD'
      end

      def commit_message(branch, integration_branch, pull_request)
        commit_message = "[gitx] Integrate #{branch} into #{integration_branch}"
        commit_message += "\n\nConnected to ##{pull_request.number}" if pull_request
        commit_message
      end

      def feature_branch_name
        @feature_branch ||= begin
          feature_branch = options[:resume] || current_branch.name
          feature_branch = ask("#{feature_branch} does not exist. Please select one of the available local branches: #{local_branches}") until local_branch_exists?(feature_branch)
          feature_branch
        end
      end

      # nuke local branch and pull fresh version from remote repo
      def fetch_remote_branch(target_branch)
        create_remote_branch(target_branch) unless remote_branch_exists?(target_branch)
        run_git_cmd 'fetch', 'origin'
        run_git_cmd('branch', '--delete', '--force', target_branch) rescue Gitx::Executor::ExecutionError
        checkout_branch target_branch
      end

      def local_branch_exists?(branch)
        local_branches.include?(branch)
      end

      def local_branches
        @local_branches ||= repo.branches.each_name(:local)
      end

      def remote_branch_exists?(target_branch)
        repo.branches.each_name(:remote).include?("origin/#{target_branch}")
      end

      def create_remote_branch(target_branch)
        repo.create_branch(target_branch, config.base_branch)
        run_git_cmd 'push', 'origin', "#{target_branch}:#{target_branch}"
      end
    end
  end
end
