require 'grit'
require 'active_support/all'
require 'highline/import'
require 'rest_client'
require 'json'

module Socialcast
  module Gitx

  end

  def current_branch
    repo = Grit::Repo.new(Dir.pwd)
    Grit::Head.current(repo).name
  end
 
  def run_cmd(cmd)
    HighLine.say "\n> <%= color('#{cmd.gsub("'", '')}', :red) %>"
    raise "#{cmd} failed" unless system cmd
  end

  def branches(options = {})
    branches = []
    reserved_branches = %w{ HEAD master last_known_good_master staging last_known_good_staging next_release last_known_good_next_release }
    args = []
    args << '-r' if options[:remote]
    args << '--merged' if options[:merged]
    output = `git branch #{args.join(' ')}`.split("\n")
    output.each do |branch|
      branch = branch.gsub(/\*/, '').strip.split(' ').first
      branch = branch.split('/').last if options[:remote]
      branches << branch unless reserved_branches.include?(branch)
    end
    branches
  end
  def reset_branch(branch, head_branch = 'master')
    return if branch == head_branch
    run_cmd "git checkout #{head_branch}"
    run_cmd "git pull"
    run_cmd "git branch -D #{branch}" rescue nil
    run_cmd "git push origin :#{branch}" rescue nil
    run_cmd "git checkout -b #{branch}"
    run_cmd "grb publish #{branch}"
    run_cmd "git checkout #{head_branch}"
  end

  def integrate(branch, destination_branch = 'staging')
    HighLine.say "integrating <%= color('#{branch}', :green) %> into <%= color('#{destination_branch}', :green) %>"
    run_cmd "git remote prune origin"
    unless destination_branch == 'master'
      run_cmd "git branch -D #{destination_branch}" rescue nil
      run_cmd "grb track #{destination_branch}"
    end
    run_cmd "git checkout #{destination_branch}"
    run_cmd "git pull . #{branch}"
    run_cmd "git push origin HEAD"

    run_cmd "git checkout #{branch}"
  end
  def create_pull_request(username, password, branch)
    response = RestClient.post "https://#{username}:#{password}@api.github.com/repos/socialcast/socialcast/pulls", {:title => branch, :base => 'master', :head => branch}.to_json, :accept => :json, :content_type => :json
    data = JSON.parse response.body
    url = data['html_url']
  end
end
