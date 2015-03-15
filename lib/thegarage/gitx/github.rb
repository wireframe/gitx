require 'octokit'
require 'fileutils'
require 'yaml'
require 'thegarage/gitx/cli/update_command'

module Thegarage
  module Gitx
    module Github
      GLOBAL_CONFIG_FILE = '~/.config/gitx/github.yml'
      REVIEW_CONTEXT = 'peer_review'
      CLIENT_URL = 'https://github.com/thegarage/thegarage-gitx'
      PULL_REQUEST_FOOTER = <<-EOS.dedent
        # Pull Request Protips(tm):
        # * Include description of how this change accomplishes the task at hand.
        # * Use GitHub flavored Markdown http://github.github.com/github-flavored-markdown/
        # * Review CONTRIBUTING.md for recommendations of artifacts, links, images, screencasts, etc.
        #
        # This footer will automatically be stripped from the pull request description
      EOS

      def find_or_create_pull_request(branch)
        pull_request = find_pull_request(branch)
        pull_request ||= begin
          checkout_branch(branch)
          execute_command(Thegarage::Gitx::Cli::UpdateCommand, :update)
          pull_request = create_pull_request(branch)
          say 'Created pull request: '
          say pull_request.html_url, :green

          pull_request
        end
        pull_request
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

      # Get the current commit status of a branch
      # @see https://developer.github.com/v3/repos/statuses/#get-the-combined-status-for-a-specific-ref
      def branch_status(branch)
        response = github_client.status(github_slug, branch)
        response.state
      end

      # Update build status with peer review status
      def update_review_status(commit_sha, state, description)
        github_client.create_status(github_slug, commit_sha, state, context: REVIEW_CONTEXT, description: description)
      end

      # @see http://developer.github.com/v3/pulls/
      def create_pull_request(branch)
        say "Creating pull request for "
        say "#{branch} ", :green
        say "against "
        say "#{Thegarage::Gitx::BASE_BRANCH} ", :green
        say "in "
        say github_slug, :green

        title = branch
        body = pull_request_body(branch)
        github_client.create_pull_request(github_slug, Thegarage::Gitx::BASE_BRANCH, branch, title, body)
      end

      def pull_request_body(branch)
        changelog = run_cmd("git log #{Thegarage::Gitx::BASE_BRANCH}...#{branch} --reverse --no-merges --pretty=format:'* %s%n%b'")
        description = options[:description]

        description_template = []
        description_template << "#{description}\n" if description
        description_template << '### Changelog'
        description_template << changelog
        description_template << PULL_REQUEST_FOOTER

        body = ask_editor(description_template.join("\n"), repo.config['core.editor'])
        body.gsub(PULL_REQUEST_FOOTER, '').chomp.strip
      end

      # authorization token used for github API calls
      # the token is cached on the filesystem for future use
      # @return [String] auth token stored in git (current repo, user config or installed global settings)
      # @see http://developer.github.com/v3/oauth/#scopes
      # @see http://developer.github.com/v3/#user-agent-required
      def authorization_token
        auth_token = global_config['token']
        auth_token ||= begin
          new_token = create_authorization
          save_global_config('token' => new_token)
          new_token
        end
        auth_token
      end

      def create_authorization
        password = ask_without_echo("Github password for #{username}: ")
        client = Octokit::Client.new(login: username, password: password)
        options = {
          :scopes => ['repo'],
          :note => github_client_name,
          :note_url => CLIENT_URL
        }
        two_factor_auth_token = ask_without_echo("Github two factor authorization token (if enabled): ")
        options[:headers] = {'X-GitHub-OTP' => two_factor_auth_token} if two_factor_auth_token
        response = client.create_authorization(options)
        response.token
      rescue Octokit::ClientError => e
        say "Error creating authorization: #{e.message}", :red
        retry
      end

      def github_client_name
        timestamp = Time.now.utc.strftime('%FT%R:%S%z')
        client_name = "The Garage Git eXtensions #{timestamp}"
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

      def global_config_file
        File.expand_path(GLOBAL_CONFIG_FILE)
      end

      def global_config
        @config ||= begin
          File.exists?(global_config_file) ? YAML.load_file(global_config_file) : {}
        end
      end

      def save_global_config(options)
        config_dir = File.dirname(global_config_file)
        ::FileUtils.mkdir_p(config_dir, mode: 0700) unless File.exists?(config_dir)

        @config = global_config.merge(options)
        File.open(global_config_file, "a+") do |file|
          file.truncate(0)
          file.write(@config.to_yaml)
        end
        File.chmod(0600, global_config_file)
      end

      def ask_without_echo(message)
        value = ask(message, echo: false)
        say ''
        value
      end
    end
  end
end
