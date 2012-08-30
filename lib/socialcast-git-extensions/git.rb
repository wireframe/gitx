require 'grit'

module Socialcast
  module Gitx
    module Git
      RESERVED_BRANCHES = %w{ HEAD master staging prototype next_release }

      def assert_not_protected_branch!(branch, action)
        raise "Cannot #{action} reserved branch" if RESERVED_BRANCHES.include?(branch) || aggregate_branch?(branch)
      end

      # lookup the current branch of the PWD
      def current_branch
        repo = Grit::Repo.new(Dir.pwd)
        Grit::Head.current(repo).name
      end

      # lookup the current repository of the PWD
      # ex: git@github.com:socialcast/socialcast-git-extensions.git
      def current_repo
        repo = `git config -z --get remote.origin.url`.strip
        repo.scan(/:(.+\/.+)\./).first.first
      end

      # retrieve a list of branches
      def branches(options = {})
        branches = []
        args = []
        args << '-r' if options[:remote]
        args << "--merged #{options[:merged]}" if options[:merged]
        output = `git branch #{args.join(' ')}`.split("\n")
        output.each do |branch|
          branch = branch.gsub(/\*/, '').strip.split(' ').first
          branch = branch.split('/').last if options[:remote]
          branches << branch unless RESERVED_BRANCHES.include?(branch)
        end
        branches.uniq
      end

      AGGREGATE_BRANCHES = %w{ staging prototype }
      # reset the specified branch to the same set of commits as the destination branch
      # used to revert commits on aggregate branches back to a known good state
      def reset_branch(branch, head_branch = 'master')
        raise "Can not reset #{branch} to #{head_branch}" if branch == head_branch
        raise "Only aggregate branches are allowed to be reset: #{AGGREGATE_BRANCHES}" unless aggregate_branch?(branch)
        say "resetting <%= color('#{branch}', :green) %> branch to <%= color('#{head_branch}', :green) %>"

        run_cmd "git checkout #{head_branch}"
        run_cmd "git pull"
        removed_branches = branches(:remote => true, :merged => "origin/#{branch}") - branches(:remote => true, :merged => "origin/#{head_branch}")
        run_cmd "git branch -D #{branch}" rescue nil
        run_cmd "git push origin :#{branch}" rescue nil
        run_cmd "git checkout -b #{branch}"
        run_cmd "grb publish #{branch}"
        run_cmd "git checkout #{head_branch}"

        removed_branches
      end

      # integrate a branch into a destination aggregate branch
      def integrate(branch, destination_branch = 'staging')
        assert_not_protected_branch!(branch, 'integrate')
        raise "Only aggregate branches are allowed for integration: #{AGGREGATE_BRANCHES}" unless aggregate_branch?(destination_branch)
        say "integrating <%= color('#{branch}', :green) %> into <%= color('#{destination_branch}', :green) %>"
        run_cmd "git remote prune origin"
        run_cmd "git checkout #{destination_branch}"
        run_cmd "git pull . #{branch}"
        run_cmd "git push origin HEAD"
        run_cmd "git checkout #{branch}"
      end

      private
      def aggregate_branch?(branch)
        AGGREGATE_BRANCHES.include?(branch) || branch.starts_with?('last_known_good')
      end
    end
  end
end
