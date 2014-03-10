require 'grit'
require 'pathname'

module Thegarage
  module Gitx
    module Git
      AGGREGATE_BRANCHES = %w{ staging prototype }
      RESERVED_BRANCHES = %w{ HEAD master next_release } + AGGREGATE_BRANCHES

      private
      def assert_not_protected_branch!(branch, action)
        raise "Cannot #{action} reserved branch" if RESERVED_BRANCHES.include?(branch) || aggregate_branch?(branch)
      end

      # lookup the current branch of the PWD
      def current_branch
        Grit::Head.current(current_repo).name
      end

      def current_repo
        @repo ||= Grit::Repo.new(Dir.pwd)
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

      # reset the specified aggregate branch to the same set of commits as the destination branch
      def nuke_branch(outdated_branch, head_branch)
        return if outdated_branch == head_branch
        fail "Only aggregate branches are allowed to be reset: #{AGGREGATE_BRANCHES}" unless aggregate_branch?(outdated_branch)
        return if migrations_need_to_be_reverted?

        say "Resetting "
        say "#{outdated_branch} ", :green
        say "branch to "
        say head_branch, :green

        run_cmd "git checkout #{Thegarage::Gitx::BASE_BRANCH}"
        run_cmd "git branch -D #{outdated_branch}", :allow_failure => true
        run_cmd "git push origin --delete #{outdated_branch}", :allow_failure => true
        run_cmd "git checkout -b #{outdated_branch} #{head_branch}"
        share_branch outdated_branch
        run_cmd "git checkout #{Thegarage::Gitx::BASE_BRANCH}"
      end

      # share the local branch in the remote repo
      def share_branch(branch)
        run_cmd "git push origin #{branch}"
        track_branch branch
      end

      def track_branch(branch)
        run_cmd "git branch --set-upstream-to origin/#{branch}"
      end

      # integrate a branch into a destination aggregate branch
      # blow away the local aggregate branch to ensure pulling into most recent "clean" branch
      def integrate_branch(branch, destination_branch)
        assert_not_protected_branch!(branch, 'integrate') unless aggregate_branch?(destination_branch)
        raise "Only aggregate branches are allowed for integration: #{AGGREGATE_BRANCHES}" unless aggregate_branch?(destination_branch) || destination_branch == Thegarage::Gitx::BASE_BRANCH
        say "Integrating "
        say "#{branch} ", :green
        say "into "
        say destination_branch, :green

        refresh_branch_from_remote destination_branch
        run_cmd "git pull . #{branch}"
        run_cmd "git push origin HEAD"
        run_cmd "git checkout #{branch}"
      end

      # nuke local branch and pull fresh version from remote repo
      def refresh_branch_from_remote(destination_branch)
        run_cmd "git branch -D #{destination_branch}", :allow_failure => true
        run_cmd "git fetch origin"
        run_cmd "git checkout #{destination_branch}"
      end

      def aggregate_branch?(branch)
        AGGREGATE_BRANCHES.include?(branch)
      end

      # launch configured editor to retreive message/string
      def editor_input(initial_text = '')
        require 'tempfile'
        Tempfile.open('reviewrequest.md') do |f|
          f << initial_text
          f.flush

          editor = ENV['EDITOR'] || 'vi'
          flags = case editor
          when 'mate', 'emacs', 'subl'
            '-w'
          when 'mvim'
            '-f'
          else
            ''
          end
          pid = fork { exec "#{editor} #{flags} #{f.path}" }
          Process.waitpid(pid)
          description = File.read(f.path)
          description.gsub(CLI::PULL_REQUEST_FOOTER, '').chomp.strip
        end
      end
    end

    def create_build_tag(branch, label)
      timestamp = Time.now.utc.strftime '%Y-%m-%d-%H-%M-%S'
      git_tag = "build-#{branch}-#{timestamp}"
      run_cmd "git tag #{git_tag} -a -m '#{label}'"
      run_cmd "git push origin #{git_tag}"
    end

    def build_tags_for_branch(branch)
      run_cmd "git fetch --tags"
      build_tags = run_cmd("git tag -l 'build-#{branch}-*'").split
      build_tags.sort
    end

    def migrations_need_to_be_reverted?
      return false unless File.exists?('db/migrate')
      outdated_migrations = run_cmd("git diff #{head_branch}...#{outdated_branch} --name-only db/migrate").split
      return false if outdated_migrations.empty?

      say "#{outdated_branch} contains migrations that may need to be reverted.  Ensure any reversable migrations are reverted on affected databases before nuking.", :red
      say 'Example commands to revert outdated migrations:'
      outdated_migrations.reverse.each do |migration|
        version = File.basename(migration).split('_').first
        say "rake db:migrate:down VERSION=#{version}"
      end
      !yes?("Are you sure you want to nuke #{outdated_branch}? (y/n) ", :green)
    end
  end
end
