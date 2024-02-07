require 'octokit'
require 'fileutils'
require 'yaml'

module Gitx
  module Github
    GLOBAL_CONFIG_FILE = '~/.config/gitx/github.yml'.freeze
    REVIEW_CONTEXT = 'peer_review'.freeze
    CLIENT_URL = 'https://github.com/wireframe/gitx'.freeze
    PULL_REQUEST_FOOTER = <<-MESSAGE.dedent
      # Pull Request Protips(tm):
      # * Describe how this change accomplishes the task at hand
      # * Use GitHub flavored Markdown http://github.github.com/github-flavored-markdown/
      # * Include links to relevent resources and related tickets
      # * Attach build artifacts, images, screenshots, screencasts, etc
      # * Review CONTRIBUTING.md for relevant workflow requirements
      #
      # This footer will automatically be stripped from the pull request description
    MESSAGE
    PULL_REQEST_TEMPLATE_FILE='.github/PULL_REQUEST_TEMPLATE.md'

    def find_or_create_pull_request(branch)
      pull_request = find_pull_request(branch)
      pull_request ||= begin
        checkout_branch(branch)
        run_git_cmd 'update'
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
    def update_review_status(pull_request, state, description)
      commit_sha = pull_request.head.sha
      github_client.create_status(github_slug, commit_sha, state, context: REVIEW_CONTEXT, description: description)
    end

    def label_pull_request(pull_request, label)
      github_client.add_labels_to_an_issue(github_slug, pull_request.number, [label])
    end

    # @see http://developer.github.com/v3/pulls/
    def create_pull_request(branch)
      say 'Creating pull request for '
      say "#{branch} ", :green
      say 'against '
      say "#{config.base_branch} ", :green
      say 'in '
      say github_slug, :green

      title = pull_request_title(branch)
      body = pull_request_body(branch)
      github_client.create_pull_request(github_slug, config.base_branch, branch, title, body)
    end

    def pull_request_body(branch)
      changelog = run_git_cmd('log', "origin/#{config.base_branch}...#{branch}", '--reverse', '--no-merges', '--pretty=format:* %B')
      description = options[:description]

      description_template = []
      description_template << "#{description}\n" if description
      description_template << changelog
      description_template << "#{pull_request_template}\n" if pull_request_template

      ask_editor(description_template.join("\n"), editor: repo.config['core.editor'], footer: PULL_REQUEST_FOOTER)
    end

    def pull_request_title(branch)
      options[:title] || branch.gsub(/[-_]/, ' ')
    end

    def pull_request_template_file
      File.expand_path(PULL_REQEST_TEMPLATE_FILE)
    end

    def pull_request_template
      @pull_request_template ||= File.exist?(pull_request_template_file) ? File.read(pull_request_template_file) : nil
    end

    # authorization token used for github API calls
    # the token is cached on the filesystem for future use
    # @return [String] auth token stored in git (current repo, user config or installed global settings)
    # @see http://developer.github.com/v3/oauth/#scopes
    # @see http://developer.github.com/v3/#user-agent-required
    def authorization_token
      auth_token = ENV['GITX_GITHUB_TOKEN'] || global_config['token']
      auth_token ||= begin
        new_token = fetch_token
        save_global_config('token' => new_token)
        new_token
      end
      auth_token
    end

    def fetch_token
      ask_without_echo("Github personal access token with repo scopes for #{username}: ")
    end

    def github_client_name
      timestamp = Time.now.utc.strftime('%FT%R:%S%z')
      "Git eXtensions #{timestamp}"
    end

    def github_client
      @github_client ||= Octokit::Client.new(access_token: authorization_token)
    end

    # @return [String] github username (ex: 'wireframe') of the current github.user
    # @raise error if github.user is not configured
    def username
      username = repo.config['github.user']
      raise "Github user not configured.  Run: `git config --global github.user 'me@email.com'`" unless username

      username
    end

    # @return the github slug for the current repository's remote origin url.
    # @example
    #   git@github.com:socialcast/wireframe/gitx.git #=> wireframe/gitx
    # @example
    #   https://github.com/wireframe/gitx.git #=> wireframe/gitx
    def github_slug
      remote = repo.config['remote.origin.url']
      remote.to_s.gsub(/\.git$/, '').split(%r{[:/]}).last(2).join('/')
    end

    def github_organization
      github_slug.split('/').first
    end

    def global_config_file
      File.expand_path(GLOBAL_CONFIG_FILE)
    end

    def global_config
      @global_config ||= File.exist?(global_config_file) ? YAML.load_file(global_config_file) : {}
    end

    def save_global_config(options)
      config_dir = File.dirname(global_config_file)
      ::FileUtils.mkdir_p(config_dir, mode: 0o700) unless File.exist?(config_dir)

      @config = global_config.merge(options)
      File.open(global_config_file, 'a+') do |file|
        file.truncate(0)
        file.write(@config.to_yaml)
      end
      File.chmod(0o600, global_config_file)
    end

    def ask_without_echo(message)
      value = ask(message, echo: false)
      say ''
      value
    end
  end
end
