class Thor
  module Actions
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
