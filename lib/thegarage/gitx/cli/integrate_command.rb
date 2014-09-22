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
            assert_integratable_branch!(branch, target_branch)

            UpdateCommand.new.update

            say "Integrating "
            say "#{branch} ", :green
            say "into "
            say target_branch, :green

            refresh_branch_from_remote target_branch
            merge_feature_branch branch
            run_cmd "git push origin HEAD"
            checkout_branch branch
          end
        end

        private

        def assert_integratable_branch!(branch, target_branch)
          assert_not_protected_branch!(branch, 'integrate') unless aggregate_branch?(target_branch)
          raise "Only aggregate branches are allowed for integration: #{AGGREGATE_BRANCHES}" unless aggregate_branch?(target_branch) || target_branch == Thegarage::Gitx::BASE_BRANCH
        end

        # nuke local branch and pull fresh version from remote repo
        def refresh_branch_from_remote(target_branch)
          run_cmd "git branch -D #{target_branch}", :allow_failure => true
          run_cmd "git fetch origin"
          checkout_branch target_branch
        end

        def merge_feature_branch(branch)
          begin
            run_cmd "git merge #{branch}"
          rescue
            say "Merge Conflict Occurred. Please fix merge conflict and rerun command with --resume #{branch} flag"
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
          @local_branches ||= repo.branches.each_name(:local).map { |branch| branch }
        end
      end
    end
  end
end
