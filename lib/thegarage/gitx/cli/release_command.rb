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
        def release
          return unless yes?("Release #{current_branch.name} to production? (y/n)", :green)

          branch = current_branch.name
          assert_not_protected_branch!(branch, 'release')
          UpdateCommand.new.update

          find_or_create_pull_request(branch)

          checkout_branch Thegarage::Gitx::BASE_BRANCH
          run_cmd "git pull origin #{Thegarage::Gitx::BASE_BRANCH}"
          run_cmd "git merge --no-ff #{branch}"
          run_cmd "git push origin HEAD"

          IntegrateCommand.new.integrate('staging')
          CleanupCommand.new.cleanup
        end
      end
    end
  end
end
