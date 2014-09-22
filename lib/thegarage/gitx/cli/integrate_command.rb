require 'thor'
require 'thegarage/gitx'
require 'thegarage/gitx/cli/base_command'
require 'thegarage/gitx/cli/update_command'

module Thegarage
  module Gitx
    module Cli
      class IntegrateCommand < BaseCommand
        desc 'integrate', 'integrate the current branch into one of the aggregate development branches (default = staging)'
        method_option :resume, :type => :string, :aliases => '-r', :desc => 'resume merging of feature-branch'
        def integrate(target_branch = 'staging')
          branch = current_branch.name
          if options[:resume]
            resume
          else
            assert_aggregate_branch!(target_branch)

            UpdateCommand.new.update

            say "Integrating "
            say "#{branch} ", :green
            say "into "
            say target_branch, :green

            create_remote_branch(target_branch) unless remote_branch_exists?(target_branch)
            refresh_branch_from_remote(target_branch)
            merge_feature_branch branch
            run_cmd "git push origin HEAD"
            checkout_branch branch
          end
        end

        private

        def assert_aggregate_branch!(target_branch)
          fail "Invalid aggregate branch: #{target_branch} must be one of supported aggregate branches #{AGGREGATE_BRANCHES}" unless aggregate_branch?(target_branch)
        end

        # nuke local branch and pull fresh version from remote repo
        def refresh_branch_from_remote(target_branch)
          run_cmd "git fetch origin"
          run_cmd "git branch -D #{target_branch}", :allow_failure => true
          checkout_branch target_branch
        end

        def merge_feature_branch(branch)
          begin
            run_cmd "git merge #{branch}"
          rescue
            say "Merge Conflict Occurred. Please fix merge conflict and rerun command with --resume #{branch} flag", :red
            exit
          end
        end

        def resume
          feature_branch = options[:resume]
          say "Resuming Integration of "
          say "#{feature_branch}", :green

          run_cmd "git push origin HEAD"
          until check_if_branch_exists? feature_branch
            feature_branch = ask("#{feature_branch} does not exist please enter the correct branch from this list #{local_branches}")
          end
          checkout_branch feature_branch
        end

        def check_if_branch_exists?(branch)
          local_branches.include?(branch)
        end

        def local_branches
          @local_branches ||= repo.branches.each_name(:local)
        end

        def remote_branch_exists?(target_branch)
          repo.branches.each_name(:remote).include?("origin/#{target_branch}")
        end

        def create_remote_branch(target_branch)
          repo.create_branch(target_branch, Thegarage::Gitx::BASE_BRANCH)
          run_cmd "git push origin #{target_branch}:#{target_branch}"
        end
      end
    end
  end
end
