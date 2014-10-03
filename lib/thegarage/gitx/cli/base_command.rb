require 'thor'
require 'pathname'
require 'rugged'
require 'thegarage/gitx'

module Thegarage
  module Gitx
    module Cli
      class BaseCommand < Thor
        include Thor::Actions

        class MergeError < Thor::Error; end

        AGGREGATE_BRANCHES = %w( staging prototype )
        RESERVED_BRANCHES = %w( HEAD master next_release ) + AGGREGATE_BRANCHES
        add_runtime_options!

        method_option :trace, :type => :boolean, :aliases => '-v'
        def initialize(*args)
          super(*args)
        end

        private

        def repo
          @repo ||= begin
            path = Dir.pwd
            Rugged::Repository.discover(path)
          end
        end

        def checkout_branch(branch_name)
          run_cmd "git checkout #{branch_name}"
        end

        # lookup the current branch of the repo
        def current_branch
          repo.branches.find(&:head?)
        end

        def aggregate_branch?(branch)
          AGGREGATE_BRANCHES.include?(branch)
        end

        def assert_not_protected_branch!(branch, action)
          raise "Cannot #{action} reserved branch" if RESERVED_BRANCHES.include?(branch) || aggregate_branch?(branch)
        end

        # helper to invoke other CLI commands
        def execute_command(command_class, method, args = [])
          command_class.new.send(method, *args)
        end
      end
    end
  end
end
