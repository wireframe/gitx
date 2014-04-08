require 'thor'
require 'thegarage/gitx'
require 'thegarage/gitx/cli/base_command'

module Thegarage
  module Gitx
    module Cli
      class TrackCommand < BaseCommand
        desc 'track', 'set the current branch to track the remote branch with the same name'
        def track
          run_cmd "git branch --set-upstream-to origin/#{current_branch.name}"
        end
      end
    end
  end
end
