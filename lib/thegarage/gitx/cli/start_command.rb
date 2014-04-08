require 'thor'
require 'thegarage/gitx'
require 'thegarage/gitx/cli/base_command'

module Thegarage
  module Gitx
    module Cli
      class StartCommand < BaseCommand
        EXAMPLE_BRANCH_NAMES = %w( api-fix-invalid-auth desktop-cleanup-avatar-markup share-form-add-edit-link )

        desc 'start', 'start a new git branch with latest changes from master'
        def start(branch_name = nil)
          until valid_new_branch_name?(branch_name)
            branch_name = ask("What would you like to name your branch? (ex: #{EXAMPLE_BRANCH_NAMES.sample})")
          end

          run_cmd "git checkout #{Thegarage::Gitx::BASE_BRANCH}"
          run_cmd 'git pull'
          run_cmd "git checkout -b #{branch_name}"
        end

        private

        def valid_new_branch_name?(branch)
          remote_branches = Rugged::Branch.each_name(repo, :remote).to_a.map { |branch| branch.split('/').last }
          branch =~ /^[A-Za-z0-9\-_]+$/ && !remote_branches.include?(branch)
        end
      end
    end
  end
end
