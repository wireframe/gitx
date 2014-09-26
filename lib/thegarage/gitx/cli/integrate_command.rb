require 'thor'
require 'thegarage/gitx'
require 'thegarage/gitx/cli/base_command'
require 'thegarage/gitx/cli/update_command'
require 'octokit'

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

          begin
            UpdateCommand.new.update
          rescue
            fail MergeError, "Merge Conflict Occurred. Please Merge Conflict Occurred. Please fix merge conflict and rerun the integrate command"
          end

          integrate_branch(branch, integration_branch) unless options[:resume]
          checkout_branch branch

          create_integrate_comment(branch)
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

        # token is cached in local git config for future use
        # @return [String] auth token stored in git (current repo, user config or installed global settings)
        # @see http://developer.github.com/v3/oauth/#scopes
        # @see http://developer.github.com/v3/#user-agent-required
        def authorization_token
          auth_token = repo.config['thegarage.gitx.githubauthtoken']
          return auth_token unless auth_token.to_s.blank?

          auth_token = create_authorization
          repo.config['thegarage.gitx.githubauthtoken'] = auth_token
          auth_token
        end

        def create_authorization
          password = ask("Github password for #{username}: ", :echo => false)
          say ''
          client = Octokit::Client.new(login: username, password: password)
          response = client.create_authorization(authorization_request_options)
          response.token
        end

        def authorization_request_options
          timestamp = Time.now.utc.strftime('%Y-%m-%dT%H:%M:%S%z')
          client_name = "The Garage Git eXtensions - #{github_slug} #{timestamp}"
          options = {
            :scopes => ['repo'],
            :note => client_name,
            :note_url => CLIENT_URL
          }
          two_factor_auth_token = ask("Github two factor authorization token (if enabled): ", :echo => false)
          say ''
          options[:headers] = {'X-GitHub-OTP' => two_factor_auth_token} if two_factor_auth_token
          options
        end

        # @return [Sawyer::Resource] data structure of pull request info if found
        # @return nil if no pull request found
        def find_pull_request(branch)
          head_reference = "#{github_organization}:#{branch}"
          params = {
            head: head_reference,
            state: 'open'
          }
          pull_requests = github_client.pull_requests(github_slug, params)
          pull_requests.first
        end

        def create_integrate_comment(branch)
          pull_request = find_pull_request(branch)
          comment = []
          comment << '[gitx] integrated into staging :twisted_rightwards_arrows:'

          # comment = comment.chomp.strip
          github_client.add_comment(github_slug, pull_request.number, comment)
        end

        def github_client
          @client ||= Octokit::Client.new(:access_token => authorization_token)
        end

        # @return [String] github username (ex: 'wireframe') of the current github.user
        # @raise error if github.user is not configured
        def username
          username = repo.config['github.user']
          fail "Github user not configured.  Run: `git config --global github.user 'me@email.com'`" unless username
          username
        end

        # @return the github slug for the current repository's remote origin url.
        # @example
        #   git@github.com:socialcast/thegarage/gitx.git #=> thegarage/gitx
        # @example
        #   https://github.com/socialcast/thegarage/gitx.git #=> thegarage/gitx
        def github_slug
          remote = repo.config['remote.origin.url']
          remote.to_s.gsub(/\.git$/,'').split(/[:\/]/).last(2).join('/')
        end

        def github_organization
          github_slug.split('/').first
        end

        def pull_request_body(branch)
          changelog = run_cmd "git log #{Thegarage::Gitx::BASE_BRANCH}...#{branch} --no-merges --pretty=format:'* %s%n%b'"
          description = options[:description]

          description_template = []
          description_template << "#{description}\n" if description
          description_template << '### Changelog'
          description_template << changelog
          description_template << PULL_REQUEST_FOOTER

          body = ask_editor(description_template.join("\n"), repo.config['core.editor'])
          body.gsub(PULL_REQUEST_FOOTER, '').chomp.strip
        end
      end
    end
  end
end
