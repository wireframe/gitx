require 'thor'
require 'thegarage/gitx'
require 'thegarage/gitx/cli/base_command'
require 'thegarage/gitx/cli/update_command'
require 'thegarage/gitx/cli/integrate_command'
require 'thegarage/gitx/cli/cleanup_command'

module Thegarage
  module Gitx
    module Cli
      class ReleaseCommand < BaseCommand
        desc 'release', 'release the current branch to production'
        def release
          return unless yes?("Release #{current_branch.name} to production? (y/n)", :green)

          branch = current_branch.name
          assert_not_protected_branch!(branch, 'release')
          UpdateCommand.new.update

          checkout_branch Thegarage::Gitx::BASE_BRANCH
          run_cmd "git pull origin #{Thegarage::Gitx::BASE_BRANCH}"
          run_cmd "git pull . #{branch}"
          run_cmd "git push origin HEAD"

          IntegrateCommand.new.integrate('staging')
          CleanupCommand.new.cleanup
        end
      end
    end
  end
end
