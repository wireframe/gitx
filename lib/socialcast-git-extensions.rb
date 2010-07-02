module Socialcast
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
    run_cmd "git branch -D #{destination_branch}"
    run_cmd "grb track #{destination_branch}"
    run_cmd "git checkout #{destination_branch}"
    run_cmd "git pull . #{branch}"
    run_cmd "git push origin HEAD"

    run_cmd "git checkout #{branch}"
  end
end