require 'thor'
require 'thegarage/gitx'
require 'thegarage/gitx/cli/base_command'

module Thegarage
  module Gitx
    module Cli
      class StartCommand < BaseCommand
        EXAMPLE_BRANCH_NAMES = %w( api-fix-invalid-auth desktop-cleanup-avatar-markup share-form-add-edit-link )
        VALID_BRANCH_NAME_REGEX = /^[A-Za-z0-9\-_]+$/

        desc 'start', 'start a new git branch with latest changes from master'
        def start(branch_name = nil)
          until valid_new_branch_name?(branch_name)
            branch_name = ask("What would you like to name your branch? (ex: #{EXAMPLE_BRANCH_NAMES.sample})")
          end

          checkout_branch Thegarage::Gitx::BASE_BRANCH
          run_cmd 'git pull'
          repo.create_branch branch_name, 'master'
          checkout_branch branch_name
        end

        private

        def valid_new_branch_name?(branch)
          return false if repo_branches.include?(branch)
          branch =~ VALID_BRANCH_NAME_REGEX
        end

        def repo_branches
          @branch_names ||= repo.branches.each_name.map do |branch|
            branch.split('/').last
          end
        end
      end
    end
  end
end
