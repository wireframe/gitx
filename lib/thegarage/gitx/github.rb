require 'octokit'

module Thegarage
  module Gitx
    module Cli
      module Github
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
            execute_command(UpdateCommand, :update)
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
      end
    end
  end
end
