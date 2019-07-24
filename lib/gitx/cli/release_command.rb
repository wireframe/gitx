require 'thor'
require 'gitx'
require 'gitx/cli/base_command'
require 'gitx/github'

module Gitx
  module Cli
    class ReleaseCommand < BaseCommand
      include Gitx::Github

      desc 'release', 'release the current branch to production'
      method_option :cleanup, type: :boolean, desc: 'cleanup merged branches after release'
      def release(branch = nil)
        branch ||= current_branch.name
        
        return unless yes?("Release #{branch} to #{config.base_branch}? (y/n)", :green)

        assert_not_protected_branch!(branch, 'release')
        checkout_branch(branch)
        run_git_cmd 'update'

        pull_request = find_or_create_pull_request(branch)
        return unless confirm_branch_status?(branch)

        checkout_branch config.base_branch
        run_git_cmd 'pull', 'origin', config.base_branch
        run_git_cmd 'merge', '--no-ff', '--message', commit_message(branch, pull_request), branch
        run_git_cmd 'push', 'origin', 'HEAD'

        after_release
      end

      private

      def commit_message(branch, pull_request)
        message = "[gitx] Release #{branch} to #{config.base_branch}"
        message += "\n\nConnected to ##{pull_request.number}"
        message
      end

      def confirm_branch_status?(branch)
        status = branch_status(branch)
        if status == 'success'
          true
        else
          yes?("Branch status is currently: #{status}.  Proceed with release? (y/n)", :red)
        end
      end

      def after_release
        after_release_scripts = config.after_release_scripts.dup
        after_release_scripts << 'git cleanup' if options[:cleanup]
        after_release_scripts.each do |cmd|
          run_cmd cmd
        end
      end
    end
  end
end
