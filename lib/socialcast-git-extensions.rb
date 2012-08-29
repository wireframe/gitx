require 'rubygems'
require 'highline/import'

module Socialcast
  module Gitx
    def protect_reserved_branches!(branch, mode)
      abort("Cannot #{mode} reserved branch") if Socialcast::Git::RESERVED_BRANCHES.include?(branch)
    end
    def run_cmd(cmd)
      HighLine.say "\n> <%= color('#{cmd.gsub("'", '')}', :red) %>"
      raise "#{cmd} failed" unless system cmd
    end
    def share(message, options = {})
      return if ARGV.delete("--quiet") || ARGV.delete("-q")
      require 'socialcast'
      require 'socialcast/message'
      Socialcast::Message.configure_from_credentials
      Socialcast::Message.create options.merge(:body => message)
      say "Message has been shared"
    end
  end
end

require 'socialcast-git-extensions/git'
require 'socialcast-git-extensions/github'
