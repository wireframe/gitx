require 'thor'
require 'thegarage/gitx'
require 'thegarage/gitx/cli/base_command'
require 'thegarage/gitx/cli/update_command'
require 'thegarage/gitx/cli/github'
require 'octokit'

module Thegarage
  module Gitx
    module Cli
      class ReviewCommand < BaseCommand
        include Github
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
        method_option :bump, :type => :boolean, :aliases => '-b', :desc => 'bump an existing pull request by posting a comment to re-review new changes'
        # @see http://developer.github.com/v3/pulls/
        def review
          fail 'Github authorization token not found' unless authorization_token

          branch = current_branch.name
          pull_request = find_or_create_pull_request(branch)
          assign_pull_request(pull_request) if options[:assignee]

          run_cmd "open #{pull_request.html_url}" if options[:open]
        end

        private

        def find_or_create_pull_request(branch)
          pull_request = find_pull_request(branch)
          if pull_request
            create_bump_comment(pull_request) if options[:bump]
            pull_request
          else
            UpdateCommand.new.update
            pull_request = create_pull_request(branch)
            say 'Pull request created: '
            say pull_request.html_url, :green

            pull_request
          end
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

        def assign_pull_request(pull_request)
          assignee = options[:assignee]
          say "Assigning pull request to "
          say assignee, :green

          title = pull_request.title
          body = pull_request.body
          options = {
            assignee: assignee
          }
          github_client.update_issue(github_slug, pull_request.number, title, body, options)
        end

        def create_bump_comment(pull_request)
          comment_template = []
          comment_template << '[gitx] review bump :tada:'
          comment_template << ''
          comment_template << '### Summary of Changes'

          comment = ask_editor(comment_template.join("\n"), repo.config['core.editor'])
          comment = comment.chomp.strip
          github_client.add_comment(github_slug, pull_request.number, comment)
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
