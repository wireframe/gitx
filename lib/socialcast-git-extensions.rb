module Socialcast
  GIT_BRANCH_FIELD = 'customfield_10010'
  IN_STAGING_FIELD = 'customfield_10020'
  JIRA_CREDENTIALS_FILE = File.expand_path('~/.jira_key')
  
  def jira_credentials
    @credentials = YAML.load_file(JIRA_CREDENTIALS_FILE).symbolize_keys!
    @credentials
  end
  def jira_server
    #make sure soap4r is installed
    require 'jira4r'
    require "highline/import.rb"

    return @jira if @jira
    if !File.exists?(JIRA_CREDENTIALS_FILE)
      input = {}
      input[:username] = HighLine.ask("JIRA username: ")
      input[:password] = HighLine.ask("JIRA password: ") { |q| q.echo = "*" }

      File.open(JIRA_CREDENTIALS_FILE, "w") do |f|
        f.write input.to_yaml
      end
    end
    File.chmod 0600, JIRA_CREDENTIALS_FILE
    credentials = jira_credentials

    begin
      @jira = Jira4R::JiraTool.new 2, "https://issues.socialcast.com"
      @jira.login credentials[:username], credentials[:password]
      return @jira
    rescue => e
      puts "Error: #{e.message}"
      File.delete config_file
      raise e
    end
  end

  def jira_in_staging(ticket, branch)
    jira_server.updateIssue ticket, [Jira4R::V2::RemoteFieldValue.new(GIT_BRANCH_FIELD, [branch]), Jira4R::V2::RemoteFieldValue.new(IN_STAGING_FIELD, ['true'])]
    issue = jira_server.getIssue ticket

    if issue.status == '1'
      puts "Transitioning ticket from 'Open' to 'In Progress'"
      start_work_action = '11'
      jira_server.progressWorkflowAction ticket, start_work_action, []
    end
  end

  def run_cmd(cmd)
    puts "\nRunning: #{cmd}"
    raise "#{cmd} failed" unless system cmd
  end

  def update(branch)
    puts "updating #{branch} to have most recent changes from master"
    run_cmd "git pull origin #{branch}"
    run_cmd 'git pull origin master'
    run_cmd 'git push origin HEAD'
  end
  def integrate(branch, destination_branch = 'staging')
    puts "integrating #{branch} into #{destination_branch}"
    run_cmd "git remote prune origin"
    run_cmd "git branch -D #{destination_branch}" rescue nil
    run_cmd "grb track #{destination_branch}"
    run_cmd "git checkout #{destination_branch}"
    run_cmd "git pull . #{branch}"
    run_cmd "git push origin HEAD"

    run_cmd "git checkout #{branch}"
  end
end