require 'thor'
require 'pathname'
require 'rugged'
require 'yaml'
require 'thegarage/gitx'

module Thegarage
  module Gitx
    module Cli
      class BaseCommand < Thor
        include Thor::Actions

        class MergeError < Thor::Error; end

        DEFAULT_CONFIG = {
          aggregate_branches: %w( staging prototype ),
          reserved_branches: %w( HEAD master next_release staging prototype ),
          taggable_branches: %w( master staging )
        }
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
          config[:aggregate_branches].include?(branch)
        end

        def assert_not_protected_branch!(branch, action)
          raise "Cannot #{action} reserved branch" if config[:reserved_branches].include?(branch) || aggregate_branch?(branch)
        end

        # helper to invoke other CLI commands
        def execute_command(command_class, method, args = [])
          command_class.new.send(method, *args)
        end

        def config
          @configuration ||= if File.exists?(".git_workflow")
            config_file = ::YAML::load_file(".git_workflow") || {}
            Thor::CoreExt::HashWithIndifferentAccess.new(DEFAULT_CONFIG.merge(config_file))
          else
            DEFAULT_CONFIG
          end
        end
      end
    end
  end
end
