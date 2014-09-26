require 'thor'
require 'thegarage/gitx'
require 'thegarage/gitx/cli/base_command'
require 'thegarage/gitx/cli/update_command'
require 'octokit'

module Thegarage
  module Gitx
    module Cli
      module Github
        CLIENT_URL = 'https://github.com/thegarage/thegarage-gitx'
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
