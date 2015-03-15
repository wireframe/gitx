require 'thor'
require 'thegarage/gitx'
require 'thegarage/gitx/cli/base_command'
require 'thegarage/gitx/github'

module Thegarage
  module Gitx
    module Cli
      class ReviewCommand < BaseCommand
        include Thegarage::Gitx::Github

        BUMP_COMMENT_PREFIX = '[gitx] review bump :tada:'
        BUMP_COMMENT_FOOTER = <<-EOS.dedent
          # Bump comments should include:
          # * summary of what changed
          #
          # This footer will automatically be stripped from the created comment
        EOS
        APPROVAL_COMMENT_PREFIX  = '[gitx] review approved :shipit:'
        APPROVAL_COMMENT_FOOTER = <<-EOS.dedent
          # Approval comments can include:
          # * feedback
          # * post-release follow-up items
          #
          # This footer will automatically be stripped from the created comment
        EOS
        REJECTION_COMMENT_PREFIX = '[gitx] review rejected'
        REJECTION_COMMENT_FOOTER = <<-EOS.dedent
          # Rejection comments should include:
          # * feedback for fixes required before approved
          #
          # This footer will automatically be stripped from the created comment
        EOS

        desc "review", "Create or update a pull request on github"
        method_option :description, :type => :string, :aliases => '-d', :desc => 'pull request description'
        method_option :assignee, :type => :string, :aliases => '-a', :desc => 'pull request assignee'
        method_option :open, :type => :boolean, :aliases => '-o', :desc => 'open the pull request in a web browser'
        method_option :bump, :type => :boolean, :aliases => '-b', :desc => 'bump an existing pull request by posting a comment to re-review new changes'
        method_option :approve, :type => :boolean, :desc => 'approve the pull request an post comment on pull request'
        method_option :reject, :type => :boolean, :desc => 'reject the pull request an post comment on pull request'
        # @see http://developer.github.com/v3/pulls/
        def review(branch = nil)
          fail 'Github authorization token not found' unless authorization_token

          branch ||= current_branch.name
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
          comment = comment_from_template(pull_request, BUMP_COMMENT_PREFIX, BUMP_COMMENT_FOOTER)
          set_review_status('pending', 'Peer review in progress')
        end

        def reject_pull_request(pull_request)
          comment = comment_from_template(pull_request, REJECTION_COMMENT_PREFIX, REJECTION_COMMENT_FOOTER)
          set_review_status('failure', 'Peer review rejected')
        end

        def approve_pull_request(pull_request)
          comment = comment_from_template(pull_request, APPROVAL_COMMENT_PREFIX, APPROVAL_COMMENT_FOOTER)
          set_review_status('success', 'Peer review approved')
        end

        def comment_from_template(pull_request, prefix, footer)
          text = ask_editor("\n\n#{footer}", repo.config['core.editor'])
          comment = [prefix, text].join("\n\n")
          comment = comment.gsub(footer, '').chomp.strip
          github_client.add_comment(github_slug, pull_request.number, comment)
        end

        def set_review_status(state, description)
          latest_commit = repo.head.target_id
          update_review_status(latest_commit, state, description)
        end
      end
    end
  end
end
