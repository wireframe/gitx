require 'thor'
require 'thegarage/gitx'
require 'thegarage/gitx/cli/base_command'

module Thegarage
  module Gitx
    module Cli
      class BuildtagCommand < BaseCommand
        TAGGABLE_BRANCHES = %w( master staging )

        desc 'buildtag', 'create a tag for the current Travis-CI build and push it back to origin'
        def buildtag
          branch = ENV['TRAVIS_BRANCH']
          pull_request = ENV['TRAVIS_PULL_REQUEST']

          raise "Unknown branch. ENV['TRAVIS_BRANCH'] is required." unless branch

          if pull_request != 'false'
            say "Skipping creation of tag for pull request: #{pull_request}"
          elsif !TAGGABLE_BRANCHES.include?(branch)
            say "Cannot create build tag for branch: #{branch}. Only #{TAGGABLE_BRANCHES} are supported."
          else
            label = "Generated tag from TravisCI build #{ENV['TRAVIS_BUILD_NUMBER']}"
            create_build_tag(branch, label)
          end
        end

        private

        def create_build_tag(branch, label)
          timestamp = Time.now.utc.strftime '%Y-%m-%d-%H-%M-%S'
          git_tag = "build-#{branch}-#{timestamp}"
          run_cmd "git tag #{git_tag} -a -m '#{label}'"
          run_cmd "git push origin #{git_tag}"
        end
      end
    end
  end
end
