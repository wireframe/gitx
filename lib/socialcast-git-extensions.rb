require 'highline/import'
require 'socialcast-git-extensions/git'
require 'socialcast-git-extensions/github'

module Socialcast
  module Gitx
    def protect_reserved_branches!(branch, mode)
      abort("Cannot #{mode} reserved branch") if Socialcast::Git::RESERVED_BRANCHES.include?(branch)
    end
    def run_cmd(cmd)
      HighLine.say "\n> <%= color('#{cmd.gsub("'", '')}', :red) %>"
      raise "#{cmd} failed" unless system cmd
    end
    def share(message, url = nil)
      return if ARGV.delete("--quiet") || ARGV.delete("-q")
      cmd = "socialcast share '#{message}'"
      cmd += " --url #{url}" if url
      run_cmd cmd
    end
  end
end
