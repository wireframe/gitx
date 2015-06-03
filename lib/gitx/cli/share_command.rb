require 'thor'
require 'gitx'
require 'gitx/cli/base_command'

module Gitx
  module Cli
    class ShareCommand < BaseCommand
      desc 'share', 'Share the current branch in the remote repository'
      def share
        run_cmd "git push origin #{current_branch.name}"
        run_cmd "git branch --set-upstream-to origin/#{current_branch.name}"
      end
    end
  end
end
