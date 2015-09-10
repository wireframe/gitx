require 'thor'
require 'gitx'
require 'gitx/cli/base_command'
require 'gitx/cli/update_command'
require 'gitx/github'

module Gitx
  module Cli
    class ReleaseCommand < BaseCommand
      include Gitx::Github

      desc 'release', 'release the current branch to production'
      method_option :cleanup, type: :boolean, desc: 'cleanup merged branches after release'
      def release(branch = nil)
        return unless yes?("Release #{current_branch.name} to #{config.base_branch}? (y/n)", :green)

        branch ||= current_branch.name
        assert_not_protected_branch!(branch, 'release')
        checkout_branch(branch)
        execute_command(UpdateCommand, :update)

        pull_request = find_or_create_pull_request(branch)
        return unless confirm_branch_status?(branch)

        checkout_branch config.base_branch
        run_cmd "git pull origin #{config.base_branch}"
        run_cmd %Q(git merge --no-ff -m "[gitx] Releasing #{branch} to #{config.base_branch} (Pull request ##{pull_request.number})" #{branch})
        run_cmd 'git push origin HEAD'

        after_release
      end

      private

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
