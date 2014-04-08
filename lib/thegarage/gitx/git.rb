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

      def integrate(target_branch = 'staging')
        update

        branch = current_branch.name
        integrate_branch(branch, target_branch)
        runner.run_cmd "git checkout #{branch}"
      end

      def current_build_tag(branch)
        last_build_tag = build_tags_for_branch(branch).last
        raise "No known good tag found for branch: #{branch}.  Verify tag exists via `git tag -l 'build-#{branch}-*'`" unless last_build_tag
        last_build_tag
      end

      # reset the specified aggregate branch to the same set of commits as the destination branch
      def nuke(outdated_branch, target_reference)
        return if outdated_branch == target_reference
        fail "Only aggregate branches are allowed to be reset: #{AGGREGATE_BRANCHES}" unless aggregate_branch?(outdated_branch)
        return if migrations_need_to_be_reverted?

        shell.say "Resetting "
        shell.say "#{outdated_branch} ", :green
        shell.say "branch to "
        shell.say target_reference, :green

        runner.run_cmd "git checkout #{Thegarage::Gitx::BASE_BRANCH}"
        runner.run_cmd "git branch -D #{outdated_branch}", :allow_failure => true
        runner.run_cmd "git push origin --delete #{outdated_branch}", :allow_failure => true
        runner.run_cmd "git checkout -b #{outdated_branch} #{target_reference}"
        runner.run_cmd "git push origin #{outdated_branch}"
        runner.run_cmd "git branch --set-upstream-to origin/#{outdated_branch}"
        runner.run_cmd "git checkout #{Thegarage::Gitx::BASE_BRANCH}"
      end

      # lookup the current branch of the repo
      def current_branch
        repo.branches.find(&:head?)
      end

      def release
        branch = current_branch.name
        assert_not_protected_branch!(branch, 'release')
        update

        runner.run_cmd "git checkout #{Thegarage::Gitx::BASE_BRANCH}"
        runner.run_cmd "git pull origin #{Thegarage::Gitx::BASE_BRANCH}"
        runner.run_cmd "git pull . #{branch}"
        runner.run_cmd "git push origin HEAD"
        integrate('staging')
        cleanup
      end

      private

      def assert_not_protected_branch!(branch, action)
        raise "Cannot #{action} reserved branch" if RESERVED_BRANCHES.include?(branch) || aggregate_branch?(branch)
      end

      # retrieve a list of branches
      def branches(options = {})
        branches = []
        args = []
        args << '-r' if options[:remote]
        args << "--merged #{options[:merged].is_a?(String) ? options[:merged] : ''}" if options[:merged]
        output = `git branch #{args.join(' ')}`.split("\n")
        output.each do |branch|
          branch = branch.gsub(/\*/, '').strip.split(' ').first
          branch = branch.split('/').last if options[:remote]
          branches << branch unless RESERVED_BRANCHES.include?(branch)
        end
        branches.uniq
      end

      # integrate a branch into a destination aggregate branch
      # blow away the local aggregate branch to ensure pulling into most recent "clean" branch
      def integrate_branch(branch, destination_branch)
        assert_not_protected_branch!(branch, 'integrate') unless aggregate_branch?(destination_branch)
        raise "Only aggregate branches are allowed for integration: #{AGGREGATE_BRANCHES}" unless aggregate_branch?(destination_branch) || destination_branch == Thegarage::Gitx::BASE_BRANCH
        shell.say "Integrating "
        shell.say "#{branch} ", :green
        shell.say "into "
        shell.say destination_branch, :green

        refresh_branch_from_remote destination_branch
        runner.run_cmd "git pull . #{branch}"
        runner.run_cmd "git push origin HEAD"
        runner.run_cmd "git checkout #{branch}"
      end

      # nuke local branch and pull fresh version from remote repo
      def refresh_branch_from_remote(destination_branch)
        runner.run_cmd "git branch -D #{destination_branch}", :allow_failure => true
        runner.run_cmd "git fetch origin"
        runner.run_cmd "git checkout #{destination_branch}"
      end

      def aggregate_branch?(branch)
        AGGREGATE_BRANCHES.include?(branch)
      end

      def build_tags_for_branch(branch)
        runner.run_cmd "git fetch --tags"
        build_tags = runner.run_cmd("git tag -l 'build-#{branch}-*'").split
        build_tags.sort
      end

      def migrations_need_to_be_reverted?
        return false unless File.exists?('db/migrate')
        outdated_migrations = runner.run_cmd("git diff #{head_branch}...#{outdated_branch} --name-only db/migrate").split
        return false if outdated_migrations.empty?

        shell.say "#{outdated_branch} contains migrations that may need to be reverted.  Ensure any reversable migrations are reverted on affected databases before nuking.", :red
        shell.say 'Example commands to revert outdated migrations:'
        outdated_migrations.reverse.each do |migration|
          version = File.basename(migration).split('_').first
          shell.say "rake db:migrate:down VERSION=#{version}"
        end
        !yes?("Are you sure you want to nuke #{outdated_branch}? (y/n) ", :green)
      end
    end
  end
end
