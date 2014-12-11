class String
  # @see http://api.rubyonrails.org/classes/String.html#method-i-strip_heredoc
  def undent
    indent = scan(/^[ \t]*(?=\S)/).min.size || 0
    gsub(/^[ \t]{#{indent}}/, '')
  end
  alias :dedent :undent

  def blank?
    self.to_s == ''
  end
end
