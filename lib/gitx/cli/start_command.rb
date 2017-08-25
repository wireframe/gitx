require 'thor'
require 'gitx'
require 'gitx/cli/base_command'

module Gitx
  module Cli
    class StartCommand < BaseCommand
      EXAMPLE_BRANCH_NAMES = %w[api-fix-invalid-auth desktop-cleanup-avatar-markup share-form-add-edit-link].freeze
      VALID_BRANCH_NAME_REGEX = /^[A-Za-z0-9\-_]+$/

      desc 'start', 'start a new git branch with latest changes from master'
      method_option :issue, type: :numeric, aliases: '-i', desc: 'Github issue number'
      def start(branch_name = nil)
        until valid_new_branch_name?(branch_name)
          branch_name = ask("What would you like to name your branch? (ex: #{EXAMPLE_BRANCH_NAMES.sample})")
        end

        checkout_branch config.base_branch
        run_git_cmd 'pull'
        repo.create_branch branch_name, config.base_branch
        checkout_branch branch_name
        run_git_cmd('commit', '--allow-empty', '--message', commit_message(branch_name))
      end

      private

      def commit_message(branch_name)
        message = "[gitx] Start work on #{branch_name}"
        message += "\n\nConnected to ##{options[:issue]}" if options[:issue]
        message
      end

      def valid_new_branch_name?(branch)
        return false if repo_branches.include?(branch)
        Rugged::Reference.valid_name?("refs/heads/#{branch}")
      end

      # get list of local and remote branches
      def repo_branches
        @branch_names ||= repo.branches.each_name.map do |branch|
          branch.gsub('origin/', '')
        end
      end
    end
  end
end
