require 'thor'
require 'gitx'
require 'gitx/cli/base_command'

module Gitx
  module Cli
    class ShareCommand < BaseCommand
      desc 'share', 'Share the current branch in the remote repository'
      def share
        run_git_cmd 'push', 'origin', current_branch.name
        run_git_cmd 'track'
      end
    end
  end
end
