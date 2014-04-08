require 'pathname'
require 'rugged'

module Thegarage
  module Gitx
    class Git
      AGGREGATE_BRANCHES = %w( staging prototype )
      RESERVED_BRANCHES = %w( HEAD master next_release ) + AGGREGATE_BRANCHES

      attr_accessor :shell, :runner, :repo

      def initialize(shell, runner, path = Dir.pwd)
        @shell = shell
        @runner = runner
        root_path = Rugged::Repository.discover(path)
        @repo = Rugged::Repository.new(root_path)
      end

      # lookup the current branch of the repo
      def current_branch
        repo.branches.find(&:head?)
      end

      private

      def assert_not_protected_branch!(branch, action)
        raise "Cannot #{action} reserved branch" if RESERVED_BRANCHES.include?(branch) || aggregate_branch?(branch)
      end

      def aggregate_branch?(branch)
        AGGREGATE_BRANCHES.include?(branch)
      end

    end
  end
end
