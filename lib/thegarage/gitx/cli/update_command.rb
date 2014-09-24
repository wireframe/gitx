require 'thor'
require 'thegarage/gitx'
require 'thegarage/gitx/cli/base_command'

module Thegarage
  module Gitx
    module Cli
      class UpdateCommand < BaseCommand
        desc 'update', 'Update the current branch with latest changes from the remote feature branch and master'
        def update
          say "Updating "
          say "#{current_branch.name} ", :green
          say "with latest changes from "
          say Thegarage::Gitx::BASE_BRANCH, :green

          update_branch(current_branch.name) if remote_branch_exists?(current_branch.name)
          update_branch(Thegarage::Gitx::BASE_BRANCH)
          run_cmd 'git push origin HEAD'
        end

        private

        def update_branch(branch)
          begin
            run_cmd "git pull origin #{branch}"
          rescue
            fail MergeError, "Merge Conflict Occurred. Please fix merge conflict and rerun the update command"
          end
        end

        def remote_branch_exists?(branch)
          repo.branches.each_name(:remote).include?("origin/#{branch}")
        end
      end
    end
  end
end
