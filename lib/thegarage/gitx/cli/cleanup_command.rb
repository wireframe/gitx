require 'thor'
require 'thegarage/gitx'
require 'thegarage/gitx/cli/base_command'

module Thegarage
  module Gitx
    module Cli
      class CleanupCommand < BaseCommand
        desc 'cleanup', 'Cleanup branches that have been merged into master from the repo'
        def cleanup
          checkout_branch Thegarage::Gitx::BASE_BRANCH
          run_cmd "git pull"
          run_cmd 'git remote prune origin'

          say "Deleting local and remote branches that have been merged into "
          say Thegarage::Gitx::BASE_BRANCH, :green
          merged_branches(remote: true).each do |branch|
            run_cmd "git push origin --delete #{branch}"
          end
          merged_branches(remote: false).each do |branch|
            run_cmd "git branch -d #{branch}"
          end
        end

        private

        # @return list of branches that have been merged
        def merged_branches(options = {})
          args = []
          args << '-r' if options[:remote]
          args << "--merged"
          output = run_cmd("git branch #{args.join(' ')}").split("\n")
          branches = output.map do |branch|
            branch = branch.gsub(/\*/, '').strip.split(' ').first
            branch = branch.split('/').last if options[:remote]
            branch
          end
          branches.uniq!
          branches -= config[:reserved_branches]
          branches.reject! { |b| aggregate_branch?(b) }

          branches
        end
      end
    end
  end
end
