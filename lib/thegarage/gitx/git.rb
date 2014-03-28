require 'pathname'
require 'rugged'

module Thegarage
  module Gitx
    class Git
      AGGREGATE_BRANCHES = %w( staging prototype )
      RESERVED_BRANCHES = %w( HEAD master next_release ) + AGGREGATE_BRANCHES
      TAGGABLE_BRANCHES = %w( master staging )

      attr_accessor :shell, :runner, :repo

      def initialize(shell, runner, path = Dir.pwd)
        @shell = shell
        @runner = runner
        root_path = Rugged::Repository.discover(path)
        @repo = Rugged::Repository.new(root_path)
      end

      def update
        shell.say 'Updating '
        shell.say "#{current_branch.name} ", :green
        shell.say "with latest changes from "
        shell.say Thegarage::Gitx::BASE_BRANCH, :green

        runner.run_cmd "git pull origin #{current_branch.name}", :allow_failure => true
        runner.run_cmd "git pull origin #{Thegarage::Gitx::BASE_BRANCH}"
        runner.run_cmd 'git push origin HEAD'
      end

      def track
        runner.run_cmd "git branch --set-upstream-to origin/#{current_branch.name}"
      end

      def share
        runner.run_cmd "git push origin #{current_branch.name}"
        track
      end

      def valid_new_branch_name?(branch)
        remote_branches = Rugged::Branch.each_name(repo, :remote).to_a.map { |branch| branch.split('/').last }
        branch =~ /^[A-Za-z0-9\-_]+$/ && !remote_branches.include?(branch)
      end

      def start(branch_name)
        runner.run_cmd "git checkout #{Thegarage::Gitx::BASE_BRANCH}"
        runner.run_cmd 'git pull'
        runner.run_cmd "git checkout -b #{branch_name}"
      end

      def cleanup
        runner.run_cmd "git checkout #{Thegarage::Gitx::BASE_BRANCH}"
        runner.run_cmd "git pull"
        runner.run_cmd 'git remote prune origin'

        shell.say "Deleting branches that have been merged into "
        shell.say Thegarage::Gitx::BASE_BRANCH, :green
        branches(:merged => true, :remote => true).each do |branch|
          runner.run_cmd "git push origin --delete #{branch}" unless aggregate_branch?(branch)
        end
        branches(:merged => true).each do |branch|
          runner.run_cmd "git branch -d #{branch}" unless aggregate_branch?(branch)
        end
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

      def buildtag
        branch = ENV['TRAVIS_BRANCH']
        pull_request = ENV['TRAVIS_PULL_REQUEST']

        raise "Unknown branch. ENV['TRAVIS_BRANCH'] is required." unless branch

        if pull_request != 'false'
          shell.say "Skipping creation of tag for pull request: #{pull_request}"
        elsif !TAGGABLE_BRANCHES.include?(branch)
          shell.say "Cannot create build tag for branch: #{branch}. Only #{TAGGABLE_BRANCHES} are supported."
        else
          label = "Generated tag from TravisCI build #{ENV['TRAVIS_BUILD_NUMBER']}"
          create_build_tag(branch, label)
        end
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

      def create_build_tag(branch, label)
        timestamp = Time.now.utc.strftime '%Y-%m-%d-%H-%M-%S'
        git_tag = "build-#{branch}-#{timestamp}"
        runner.run_cmd "git tag #{git_tag} -a -m '#{label}'"
        runner.run_cmd "git push origin #{git_tag}"
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
