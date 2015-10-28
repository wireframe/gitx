require 'thor'
require 'gitx'
require 'gitx/cli/base_command'
require 'gitx/github'

module Gitx
  module Cli
    class ReviewCommand < BaseCommand
      include Gitx::Github

      BUMP_COMMENT_PREFIX = '[gitx] review bump :tada:'
      BUMP_COMMENT_FOOTER = <<-EOS.dedent
        # Bump comments should include:
        # * Summary of what changed
        #
        # This footer will automatically be stripped from the created comment
      EOS
      APPROVAL_COMMENT_PREFIX  = '[gitx] review approved :shipit:'
      APPROVAL_COMMENT_FOOTER = <<-EOS.dedent
        # Approval comments can include:
        # * Feedback
        # * Follow-up items for after release
        #
        # This footer will automatically be stripped from the created comment
      EOS
      REJECTION_COMMENT_PREFIX = '[gitx] review rejected'
      REJECTION_COMMENT_FOOTER = <<-EOS.dedent
        # Rejection comments should include:
        # * Feedback
        # * Required changes before approved
        #
        # This footer will automatically be stripped from the created comment
      EOS

      desc 'review', 'Create or update a pull request on github'
      method_option :title, type: :string, aliases: '-t', desc: 'pull request title'
      method_option :description, type: :string, aliases: '-d', desc: 'pull request description'
      method_option :assignee, type: :string, aliases: '-a', desc: 'pull request assignee'
      method_option :open, type: :boolean, aliases: '-o', desc: 'open the pull request in a web browser'
      method_option :bump, type: :boolean, aliases: '-b', desc: 'bump an existing pull request by posting a comment to re-review new changes'
      method_option :approve, type: :boolean, desc: 'approve the pull request an post comment on pull request'
      method_option :reject, type: :boolean, desc: 'reject the pull request an post comment on pull request'
      # @see http://developer.github.com/v3/pulls/
      def review(branch = nil)
        fail 'Github authorization token not found' unless authorization_token

        branch ||= current_branch.name
        pull_request = find_or_create_pull_request(branch)
        bump_pull_request(pull_request) if options[:bump]
        approve_pull_request(pull_request) if options[:approve]
        reject_pull_request(pull_request) if options[:reject]
        assign_pull_request(pull_request) if options[:assignee]

        run_cmd('open', pull_request.html_url) if options[:open]
      end

      private

      def assign_pull_request(pull_request)
        assignee = options[:assignee]
        say 'Assigning pull request to '
        say assignee, :green

        title = pull_request.title
        body = pull_request.body
        options = {
          assignee: assignee
        }
        github_client.update_issue(github_slug, pull_request.number, title, body, options)
      end

      def bump_pull_request(pull_request)
        comment_from_template(pull_request, BUMP_COMMENT_PREFIX, BUMP_COMMENT_FOOTER)
        update_review_status(pull_request, 'pending', 'Peer review in progress')
      end

      def reject_pull_request(pull_request)
        comment_from_template(pull_request, REJECTION_COMMENT_PREFIX, REJECTION_COMMENT_FOOTER)
        update_review_status(pull_request, 'failure', 'Peer review rejected')
      end

      def approve_pull_request(pull_request)
        comment_from_template(pull_request, APPROVAL_COMMENT_PREFIX, APPROVAL_COMMENT_FOOTER)
        update_review_status(pull_request, 'success', 'Peer review approved')
      end

      def comment_from_template(pull_request, prefix, footer)
        text = ask_editor('', editor: repo.config['core.editor'], footer: footer)
        comment = [prefix, text].join("\n\n")
        comment = comment.chomp.strip
        github_client.add_comment(github_slug, pull_request.number, comment)
      end
    end
  end
end
