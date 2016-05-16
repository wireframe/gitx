class String
  # @see http://api.rubyonrails.org/classes/String.html#method-i-strip_heredoc
  def undent
    indent = scan(/^[ \t]*(?=\S)/).min.size || 0
    gsub(/^[ \t]{#{indent}}/, '')
  end
  alias dedent undent

  def blank?
    to_s == ''
  end

  # @see http://apidock.com/rails/ActiveSupport/CoreExtensions/String/StartsEndsWith/starts_with%
  def starts_with?(prefix)
    prefix.respond_to?(:to_str) && self[0, prefix.length] == prefix
  end
end
