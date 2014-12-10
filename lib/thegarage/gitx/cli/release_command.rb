require 'thor'
require 'thegarage/gitx'
require 'thegarage/gitx/cli/base_command'
require 'thegarage/gitx/cli/update_command'
require 'thegarage/gitx/cli/integrate_command'
require 'thegarage/gitx/cli/cleanup_command'
require 'thegarage/gitx/github'

module Thegarage
  module Gitx
    module Cli
      class ReleaseCommand < BaseCommand
        include Github

        desc 'release', 'release the current branch to production'
        method_option :cleanup, :type => :boolean, :desc => 'cleanup merged branches after release'
        def release
          return unless yes?("Release #{current_branch.name} to production? (y/n)", :green)

          branch = current_branch.name
          assert_not_protected_branch!(branch, 'release')
          execute_command(UpdateCommand, :update)

          find_or_create_pull_request(branch)
          status = branch_status(branch)
          if status != 'success'
            return unless yes?("Branch status is currently: #{status}.  Proceed with release? (y/n)", :red)
          end

          checkout_branch Thegarage::Gitx::BASE_BRANCH
          run_cmd "git pull origin #{Thegarage::Gitx::BASE_BRANCH}"
          run_cmd "git merge --no-ff #{branch}"
          run_cmd "git push origin HEAD"

          execute_command(IntegrateCommand, :integrate, 'staging')
          execute_command(CleanupCommand, :cleanup) if options[:cleanup]
        end
      end
    end
  end
end
