require 'thor'
require 'gitx'
require 'gitx/cli/base_command'
require 'gitx/cli/update_command'
require 'gitx/cli/integrate_command'
require 'gitx/cli/cleanup_command'
require 'gitx/github'

module Gitx
  module Cli
    class ReleaseCommand < BaseCommand
      include Gitx::Github

      desc 'release', 'release the current branch to production'
      method_option :cleanup, type: :boolean, desc: 'cleanup merged branches after release'
      def release(branch = nil)
        return unless yes?("Release #{current_branch.name} to production? (y/n)", :green)

        branch ||= current_branch.name
        assert_not_protected_branch!(branch, 'release')
        checkout_branch(branch)
        execute_command(UpdateCommand, :update)

        find_or_create_pull_request(branch)
        status = branch_status(branch)
        if status != 'success'
          return unless yes?("Branch status is currently: #{status}.  Proceed with release? (y/n)", :red)
        end

        checkout_branch Gitx::BASE_BRANCH
        run_cmd "git pull origin #{Gitx::BASE_BRANCH}"
        run_cmd "git merge --no-ff #{branch}"
        run_cmd 'git push origin HEAD'

        execute_command(IntegrateCommand, :integrate, 'staging')
        execute_command(CleanupCommand, :cleanup) if options[:cleanup]
      end
    end
  end
end
