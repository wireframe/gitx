require 'English'

class Thor
  module Actions
    # execute a shell command and raise an error if non-zero exit code is returned
    # return the string output from the command
    def run_cmd(cmd, options = {})
      say "$ #{cmd}"
      output = `#{cmd}`
      success = $CHILD_STATUS.to_i == 0
      fail "#{cmd} failed" unless success || options[:allow_failure]
      output
    end

    # launch configured editor to retreive message/string
    # see http://osdir.com/ml/ruby-talk/2010-06/msg01424.html
    # see https://gist.github.com/rkumar/456809
    # see http://rdoc.info/github/visionmedia/commander/master/Commander/UI.ask_editor
    def ask_editor(initial_text = '', editor = nil)
      editor ||= ENV['EDITOR'] || 'vi'
      Tempfile.open('reviewrequest.md') do |f|
        f << initial_text
        f.flush

        flags = case editor
        when 'mate', 'emacs', 'subl'
          '-w'
        when 'mvim'
          '-f'
        else
          ''
        end
        pid = fork { exec([editor, flags, f.path].join(' ')) }
        Process.waitpid(pid)
        File.read(f.path)
      end
    end
  end
end
