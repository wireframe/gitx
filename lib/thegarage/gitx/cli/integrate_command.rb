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
        def integrate(integration_branch = 'staging')
          assert_aggregate_branch!(integration_branch)

          branch = feature_branch_name
          print_message(branch, integration_branch)

          UpdateCommand.new.update

          integrate_branch(branch, integration_branch) unless options[:resume]
          checkout_branch branch
        end

        private

        def print_message(branch, integration_branch)
          message = options[:resume] ? 'Resuming integration of' : 'Integrating'
          say "#{message} "
          say "#{branch} ", :green
          say "into "
          say integration_branch, :green
        end

        def integrate_branch(branch, integration_branch)
          fetch_remote_branch(integration_branch)
          begin
            run_cmd "git merge #{branch}"
          rescue
            fail MergeError, "Merge Conflict Occurred. Please fix merge conflict and rerun command with --resume #{branch} flag"
          end
          run_cmd "git push origin HEAD"
        end

        def feature_branch_name
          @feature_branch ||= begin
            feature_branch = options[:resume] || current_branch.name
            until local_branch_exists?(feature_branch)
              feature_branch = ask("#{feature_branch} does not exist. Please select one of the available local branches: #{local_branches}")
            end
            feature_branch
          end
        end

        def assert_aggregate_branch!(target_branch)
          fail "Invalid aggregate branch: #{target_branch} must be one of supported aggregate branches #{AGGREGATE_BRANCHES}" unless aggregate_branch?(target_branch)
        end

        # nuke local branch and pull fresh version from remote repo
        def fetch_remote_branch(target_branch)
          create_remote_branch(target_branch) unless remote_branch_exists?(target_branch)
          run_cmd "git fetch origin"
          run_cmd "git branch -D #{target_branch}", :allow_failure => true
          checkout_branch target_branch
        end

        def local_branch_exists?(branch)
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
