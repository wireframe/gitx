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

        begin
          execute_command(UpdateCommand, :update)
        rescue
          raise MergeError, 'Merge conflict occurred.  Please fix merge conflict and rerun the integrate command'
        end

        pull_request = pull_request_for_branch(branch)
        integrate_branch(branch, integration_branch, pull_request) unless options[:resume]
        checkout_branch branch
        create_integrate_comment(pull_request) if pull_request
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
        commit_message = "[gitx] Integrating #{branch} into #{integration_branch}"
        commit_message += " (Pull request ##{pull_request.number})" if pull_request
        begin
          run_cmd %Q(git merge --no-ff -m "#{commit_message}" #{branch})
        rescue
          raise MergeError, "Merge conflict occurred.  Please fix merge conflict and rerun command with --resume #{branch} flag"
        end
        run_cmd 'git push origin HEAD'
      end

      def feature_branch_name
        @feature_branch ||= begin
          feature_branch = options[:resume] || current_branch.name
          until local_branch_exists?(feature_branch)
            feature_branch = ask("#{feature_branch} does not exist. Please select one of the available local branches: #{local_branches}")
          end
          feature_branch
        end
      end

      # nuke local branch and pull fresh version from remote repo
      def fetch_remote_branch(target_branch)
        create_remote_branch(target_branch) unless remote_branch_exists?(target_branch)
        run_cmd 'git fetch origin'
        run_cmd "git branch -D #{target_branch}", allow_failure: true
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
        repo.create_branch(target_branch, Gitx::BASE_BRANCH)
        run_cmd "git push origin #{target_branch}:#{target_branch}"
      end

      def create_integrate_comment(pull_request)
        comment = '[gitx] integrated into staging :twisted_rightwards_arrows:'
        github_client.add_comment(github_slug, pull_request.number, comment)
      end
    end
  end
end
