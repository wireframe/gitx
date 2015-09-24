require 'thor'
require 'pathname'
require 'rugged'
require 'gitx'
require 'gitx/executor'

module Gitx
  module Cli
    class BaseCommand < Thor
      include Thor::Actions

      class MergeError < Thor::Error; end

      add_runtime_options!

      method_option :trace, type: :boolean, aliases: '-v'
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

      def run_cmd(*cmd)
        executor.execute(*cmd) do |output|
          say(output, :yellow) if options[:trace]
        end
      end

      def run_git_cmd(*cmd)
        run_cmd('git', *cmd)
      end

      def checkout_branch(branch_name)
        run_git_cmd 'checkout', branch_name
      end

      # lookup the current branch of the repo
      def current_branch
        repo.branches.find(&:head?)
      end

      def assert_aggregate_branch!(target_branch)
        fail "Invalid aggregate branch: #{target_branch} must be one of supported aggregate branches #{config.aggregate_branches}" unless config.aggregate_branch?(target_branch)
      end

      def assert_not_protected_branch!(branch, action)
        fail "Cannot #{action} reserved branch" if config.reserved_branch?(branch) || config.aggregate_branch?(branch)
      end

      # helper to invoke other CLI commands
      def execute_command(command_class, method, args = [])
        command_class.new.send(method, *args)
      end

      def config
        @configuration ||= Gitx::Configuration.new(repo.workdir)
      end

      def executor
        @executor ||= Gitx::Executor.new
      end
    end
  end
end
