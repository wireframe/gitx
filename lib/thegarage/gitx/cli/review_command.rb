require 'thor'
require 'thegarage/gitx'
require 'thegarage/gitx/cli/base_command'
require 'thegarage/gitx/cli/update_command'
require 'thegarage/gitx/github'

module Thegarage
  module Gitx
    module Cli
      class ReviewCommand < BaseCommand
        include Thegarage::Gitx::Github

        BUMP_COMMENT_TEMPLATE = <<-EOS.dedent
          [gitx] review bump :tada:

          ### Changelog Summary
        EOS
        APPROVAL_COMMENT_TEMPLATE = <<-EOS.dedent
          [gitx] review approved :shipit:

          ### Feedback

          ### Follow-up Items
        EOS
        REJECTION_COMMENT_TEMPLATE = <<-EOS.dedent
          [gitx] review rejected

          ### Feedback
        EOS

        desc "review", "Create or update a pull request on github"
        method_option :description, :type => :string, :aliases => '-d', :desc => 'pull request description'
        method_option :assignee, :type => :string, :aliases => '-a', :desc => 'pull request assignee'
        method_option :open, :type => :boolean, :aliases => '-o', :desc => 'open the pull request in a web browser'
        method_option :bump, :type => :boolean, :aliases => '-b', :desc => 'bump an existing pull request by posting a comment to re-review new changes'
        method_option :approve, :type => :boolean, :desc => 'approve the pull request an post comment on pull request'
        method_option :reject, :type => :boolean, :desc => 'reject the pull request an post comment on pull request'
        # @see http://developer.github.com/v3/pulls/
        def review
          fail 'Github authorization token not found' unless authorization_token

          branch = current_branch.name
          pull_request = find_or_create_pull_request(branch)
          bump_pull_request(pull_request) if options[:bump]
          approve_pull_request(pull_request) if options[:approve]
          reject_pull_request(pull_request) if options[:reject]
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

        def bump_pull_request(pull_request)
          comment = get_editor_input(BUMP_COMMENT_TEMPLATE)
          github_client.add_comment(github_slug, pull_request.number, comment)

          set_review_status('pending', 'Peer review in progress')
        end

        def reject_pull_request(pull_request)
          comment = get_editor_input(REJECTION_COMMENT_TEMPLATE)
          github_client.add_comment(github_slug, pull_request.number, comment)

          set_review_status('failure', 'Peer review rejected')
        end

        def approve_pull_request(pull_request)
          comment = get_editor_input(APPROVAL_COMMENT_TEMPLATE)
          github_client.add_comment(github_slug, pull_request.number, comment)

          set_review_status('success', 'Peer review approved')
        end

        def get_editor_input(template)
          text = ask_editor(template, repo.config['core.editor'])
          text = text.chomp.strip
        end

        def set_review_status(state, description)
          latest_commit = repo.head.target_id
          update_review_status(latest_commit, state, description)
        end
      end
    end
  end
end
