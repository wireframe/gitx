require 'thor'
require 'thegarage/gitx'
require 'thegarage/gitx/cli/base_command'
require 'thegarage/gitx/cli/update_command'
require 'octokit'

module Thegarage
  module Gitx
    module Cli
      class ReviewCommand < BaseCommand
        CLIENT_URL = 'https://github.com/thegarage/thegarage-gitx'
        PULL_REQUEST_FOOTER = <<-EOS.dedent
          # Pull Request Protips(tm):
          # * Include description of how this change accomplishes the task at hand.
          # * Use GitHub flavored Markdown http://github.github.com/github-flavored-markdown/
          # * Review CONTRIBUTING.md for recommendations of artifacts, links, images, screencasts, etc.
          #
          # This footer will automatically be stripped from the pull request description
        EOS

        desc "review", "Create or update a pull request on github"
        method_option :description, :type => :string, :aliases => '-d', :desc => 'pull request description'
        method_option :assignee, :type => :string, :aliases => '-a', :desc => 'pull request assignee'
        method_option :open, :type => :boolean, :aliases => '-o', :desc => 'open the pull request in a web browser'
        # @see http://developer.github.com/v3/pulls/
        def review
          fail 'Github authorization token not found' unless authorization_token

          branch = current_branch.name
          pull_request = find_pull_request(branch)
          if pull_request.nil?
            UpdateCommand.new.update
            pull_request = create_pull_request(branch)
            say 'Pull request created: '
            say pull_request.html_url, :green
          end
          assign_pull_request(pull_request, options[:assignee]) if options[:assignee]

          run_cmd "open #{pull_request.html_url}" if options[:open]
        end

        private

        # token is cached in local git config for future use
        # @return [String] auth token stored in git (current repo, user config or installed global settings)
        # @see http://developer.github.com/v3/oauth/#scopes
        # @see http://developer.github.com/v3/#user-agent-required
        def authorization_token
          auth_token = repo.config['thegarage.gitx.githubauthtoken']
          return auth_token unless auth_token.to_s.blank?

          password = ask("Github password for #{username}: ", :echo => false)
          say ''
          two_factor_auth_token = ask("Github two factor authorization token (if enabled): ", :echo => false)

          timestamp = Time.now.utc.strftime('%Y-%m-%dT%H:%M:%S%z')
          client_name = "The Garage Git eXtensions - #{remote_origin_name} #{timestamp}"
          options = {
            :scopes => ['repo'],
            :note => client_name,
            :note_url => CLIENT_URL
          }
          options[:headers] = {'X-GitHub-OTP' => two_factor_auth_token} if two_factor_auth_token
          client = Octokit::Client.new(login: username, password: password)
          response = client.create_authorization(options)
          token = response.token
          repo.config['thegarage.gitx.githubauthtoken'] = token
          token
        end

        # @see http://developer.github.com/v3/pulls/
        def create_pull_request(branch)
          say "Creating pull request for "
          say "#{branch} ", :green
          say "against "
          say "#{Thegarage::Gitx::BASE_BRANCH} ", :green
          say "in "
          say remote_origin_name, :green

          client = Octokit::Client.new(:access_token => authorization_token)
          title = branch
          body = pull_request_body(branch)
          client.create_pull_request(remote_origin_name, Thegarage::Gitx::BASE_BRANCH, branch, title, body)
        end

        def assign_pull_request(pull_request, assignee)
          say "Assigning pull request to "
          say assignee, :green

          client = Octokit::Client.new(:access_token => authorization_token)
          title = pull_request.title
          body = pull_request.body
          options = {
            assignee: assignee
          }
          client.update_issue(remote_origin_name, pull_request.number, title, body, options)
        end

        # @return [Sawyer::Resource] data structure of pull request info if found
        # @return nil if no pull request found
        def find_pull_request(branch)
          head_reference = "#{repo_organization_name}:#{branch}"
          params = {
            head: head_reference,
            state: 'open'
          }
          client = Octokit::Client.new(:access_token => authorization_token)
          pull_requests = client.pull_requests(remote_origin_name, params)
          pull_requests.first
        end

        # @return [String] github username (ex: 'wireframe') of the current github.user
        # @raise error if github.user is not configured
        def username
          username = repo.config['github.user']
          fail "Github user not configured.  Run: `git config --global github.user 'me@email.com'`" unless username
          username
        end

        # lookup the current repository of the PWD
        # ex: git@github.com:socialcast/thegarage/gitx.git OR https://github.com/socialcast/thegarage/gitx.git
        def remote_origin_name
          remote = repo.config['remote.origin.url']
          remote.to_s.gsub(/\.git$/,'').split(/[:\/]/).last(2).join('/')
        end

        def repo_organization_name
          remote_origin_name.split('/').first
        end

        def pull_request_body(branch)
          changelog = run_cmd "git log #{Thegarage::Gitx::BASE_BRANCH}...#{branch} --no-merges --pretty=format:'* %s%n%b'"
          description = options[:description]

          description_template = []
          description_template << "#{description}\n" if description
          description_template << '### Changelog'
          description_template << changelog
          description_template << PULL_REQUEST_FOOTER

          body = input_from_editor(description_template.join("\n"))
          body.gsub(PULL_REQUEST_FOOTER, '').chomp.strip
        end

        # launch configured editor to retreive message/string
        def input_from_editor(initial_text = '')
          Tempfile.open('reviewrequest.md') do |f|
            f << initial_text
            f.flush

            editor = repo.config['core.editor'] || ENV['EDITOR'] || 'vi'
            flags = case editor
            when 'mate', 'emacs', 'subl'
              '-w'
            when 'mvim'
              '-f'
            else
              ''
            end
            pid = fork { exec([editor, flags, f.path].join(' ')) }
            Process.waitpid(pid)
            File.read(f.path)
          end
        end
      end
    end
  end
end
