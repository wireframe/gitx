require 'thor'
require 'thegarage/gitx'
require 'thegarage/gitx/cli/base_command'

module Thegarage
  module Gitx
    module Cli
      class CleanupCommand < BaseCommand
        desc 'cleanup', 'Cleanup branches that have been merged into master from the repo'
        def cleanup
          run_cmd "git checkout #{Thegarage::Gitx::BASE_BRANCH}"
          run_cmd "git pull"
          run_cmd 'git remote prune origin'

          say "Deleting local and remote branches that have been merged into "
          say Thegarage::Gitx::BASE_BRANCH, :green
          merged_remote_branches.each do |branch|
            run_cmd "git push origin --delete #{branch}"
          end
          merged_local_branches.each do |branch|
            run_cmd "git branch -d #{branch}"
          end
        end

        private

        def merged_local_branches
          branches(:merged => true).reject { |b| aggregate_branch?(b) }
        end

        def merged_remote_branches
          branches(:merged => true, :remote => true).reject { |b| aggregate_branch?(b) }
        end
      end
    end
  end
end
