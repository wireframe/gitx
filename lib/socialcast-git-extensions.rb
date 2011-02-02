require 'jira4r'
require 'grit'
require 'active_support/all'
require 'highline/import'

module Socialcast
  GIT_BRANCH_FIELD = 'customfield_10010'
  IN_PROTOTYPE_FIELD = 'customfield_10033'
  IN_STAGING_FIELD = 'customfield_10020'
  JIRA_CREDENTIALS_FILE = File.expand_path('~/.jira_key')

  def current_branch
    repo = Grit::Repo.new(Dir.pwd)
    Grit::Head.current(repo).name
  end
  def jira_credentials
    @credentials ||= YAML.load_file(JIRA_CREDENTIALS_FILE).symbolize_keys!
    @credentials
  end
  def jira_server
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
      print_error e.message
      File.delete config_file
      raise e
    end
  end

  def assert_tickets_provided(ticket_ids, branch)
    tickets = tickets_from_arguments_or_branch(ticket_ids, branch)
    raise "JIRA ticket id or existing JIRA Git Branch is required to run this process" unless tickets.any?
    tickets
  end
  def tickets_from_arguments_or_branch(ticket_ids, branch)
    ticket_ids.any? ? tickets_from_arguments(ticket_ids) : tickets_from_branch(branch)
  end
  def tickets_from_arguments(ticket_ids)
    ticket_ids.collect do |key|
      jira_server.getIssue key
    end
  end
  def tickets_from_branch(branch)
    jira_server.getIssuesFromJqlSearch "project = 'SCWEBAPP' and 'Git Branch' ~ '#{branch}'", 1000
  end
  def update_tickets(tickets, options = {})
    tickets.each do |ticket|
      print_issue ticket
      fields = []
      fields << Jira4R::V2::RemoteFieldValue.new(GIT_BRANCH_FIELD, [options[:branch]]) unless options[:branch].nil?
      fields << Jira4R::V2::RemoteFieldValue.new(IN_PROTOTYPE_FIELD, [options[:in_prototype].to_s]) unless options[:in_prototype].nil?
      fields << Jira4R::V2::RemoteFieldValue.new(IN_STAGING_FIELD, [options[:in_staging] ? 'true' : '']) unless options[:in_staging].nil?
      begin
        jira_server.updateIssue ticket.key, fields
      rescue => e
        print_error e.message
      end
    end
  end
  STANDARD_WORKFLOW_TYPES = []
  STANDARD_WORKFLOW_TYPES << 1 #bug
  STANDARD_WORKFLOW_TYPES << 2 #feature
  STANDARD_WORKFLOW_TYPES << 9 #story

  WORKFLOW_MAPPINGS {
    :start => {:standard => 11, :other => 21},
    :resolve => {:standard => 21, :other => nil},
    :release => {:standard => 101, :other => 31}
  }
  def start_tickets(tickets)
    transition_tickets tickets, :start
  end
  def resolve_tickets(tickets)
    start_tickets tickets
    transition_tickets tickets, :resolve
  end
  def release_tickets(tickets)
    resolve_tickets tickets
    transition_tickets tickets, :release
  end
  def transition_tickets(tickets, action)
    tickets.each do |ticket|
      begin
        mappings = WORKFLOW_MAPPINGS[action]
        transition = STANDARD_WORKFLOW_TYPES.include?(ticket.type.to_i) ? mappings[:standard] : mappings[:other]
        next unless transition
        jira_server.progressWorkflowAction ticket.key, transition.to_s, []
      rescue => e
        print_error "Unable to transition issue #{ticket.key} to #{action}"
      end
    end
  end
  def print_issue(issue)
    HighLine.say "<%= color('#{issue.key}', :green) %> - #{issue.summary}"
  end
  def print_error(message)
    HighLine.say "<%= color('Error: ', :red) %> - #{message}"
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
  def reset_branch(branch)
    run_cmd "git checkout master"
    run_cmd "git pull"
    run_cmd "git branch -D #{branch}" rescue nil
    run_cmd "git push origin :#{branch}" rescue nil
    run_cmd "git checkout -b #{branch}"
    run_cmd "grb publish #{branch}"
    run_cmd "git checkout master"
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
end