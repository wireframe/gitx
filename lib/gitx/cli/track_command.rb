require 'thor'
require 'gitx'
require 'gitx/cli/base_command'

module Gitx
  module Cli
    class TrackCommand < BaseCommand
      desc 'track', 'set the current branch to track the remote branch with the same name'
      def track
        run_git_cmd 'branch', '--set-upstream-to', "origin/#{current_branch.name}"
      end
    end
  end
end
