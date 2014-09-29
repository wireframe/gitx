require 'thor'
require 'thegarage/gitx'
require 'thegarage/gitx/cli/base_command'
require 'thegarage/gitx/cli/update_command'
require 'thegarage/gitx/github'

module Thegarage
  module Gitx
    module Cli
      class ReviewCommand < BaseCommand
        include Github

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
          create_bump_comment(pull_request) if options[:bump]
          assign_pull_request(pull_request) if options[:assignee]

          run_cmd "open #{pull_request.html_url}" if options[:open]
        end

        private

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
      end
    end
  end
end
