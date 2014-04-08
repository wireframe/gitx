require 'thor'
require 'thegarage/gitx'
require 'thegarage/gitx/cli/base_command'

module Thegarage
  module Gitx
    module Cli
      class UpdateCommand < BaseCommand
        desc 'update', 'Update the current branch with latest changes from the remote feature branch and master'
        def update
          say 'Updating '
          say "#{current_branch.name} ", :green
          say "with latest changes from "
          say Thegarage::Gitx::BASE_BRANCH, :green

          run_cmd "git pull origin #{current_branch.name}", :allow_failure => true
          run_cmd "git pull origin #{Thegarage::Gitx::BASE_BRANCH}"
          run_cmd 'git push origin HEAD'
        end
      end
    end
  end
end
