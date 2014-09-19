require 'thor'
require 'thegarage/gitx'
require 'thegarage/gitx/cli/base_command'
require 'thegarage/gitx/cli/update_command'

module Thegarage
  module Gitx
    module Cli
      class IntegrateCommand < BaseCommand
        desc 'integrate', 'integrate the current branch into one of the aggregate development branches (default = staging)'
        def integrate(target_branch = 'staging')
          branch = current_branch.name
          assert_aggregate_branch!(target_branch)

          UpdateCommand.new.update

          say "Integrating "
          say "#{branch} ", :green
          say "into "
          say target_branch, :green

          create_remote_branch(target_branch) unless remote_branch_exists?(target_branch)
          refresh_branch_from_remote(target_branch)
          run_cmd "git merge #{branch}"
          run_cmd "git push origin HEAD"
          checkout_branch branch
        end

        private

        def assert_aggregate_branch!(target_branch)
          fail "Invalid aggregate branch: #{target_branch} must be one of supported aggregate branches #{AGGREGATE_BRANCHES}" unless aggregate_branch?(target_branch)
        end

        # nuke local branch and pull fresh version from remote repo
        def refresh_branch_from_remote(target_branch)
          run_cmd "git fetch origin"
          run_cmd "git branch -D #{target_branch}", :allow_failure => true
          checkout_branch target_branch
        end

        def remote_branch_exists?(target_branch)
          repo.branches.each_name(:remote).include?("origin/#{target_branch}")
        end

        def create_remote_branch(target_branch)
          repo.create_branch(target_branch, Thegarage::Gitx::BASE_BRANCH)
          run_cmd "git push origin #{target_branch}:#{target_branch}"
        end
      end
    end
  end
end
