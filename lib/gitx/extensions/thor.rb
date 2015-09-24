require 'open3'

class Thor
  module Actions
    # execute a shell command and raise an error if non-zero exit code is returned
    # return the string output from the command
    def run_cmd(*args)
      options = args.last.is_a?(Hash) ? args.pop : {}
      cmd = args
      say "$ #{cmd.join(' ')}", :yellow
      output = ''

      Open3.popen2e(*cmd) do |stdin, stdout_err, wait_thr|
        while line = stdout_err.gets
          say(line, :yellow) if options[:trace]
          output << line
        end

        exit_status = wait_thr.value
        fail "#{cmd.join(' ')} failed" unless exit_status.success? || options[:allow_failure]
      end
      output
    end

    # launch configured editor to retreive message/string
    # see http://osdir.com/ml/ruby-talk/2010-06/msg01424.html
    # see https://gist.github.com/rkumar/456809
    # see http://rdoc.info/github/visionmedia/commander/master/Commander/UI.ask_editor
    def ask_editor(initial_text = '', editor: nil, footer: nil)
      editor ||= ENV['EDITOR'] || 'vi'
      initial_text += "\n\n#{footer}" if footer
      text = Tempfile.open('text.md') do |f|
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
      text = text.gsub(footer, '') if footer
      text.chomp.strip
    end
  end
end
