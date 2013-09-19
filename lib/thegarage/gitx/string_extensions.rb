class String
  def undent
    a = $1 if match(/\A(\s+)(.*\n)(?:\1.*\n)*\z/)
    gsub(/^#{a}/,'')
  end
  alias :dedent :undent

  def starts_with?(characters)
    !!self.match(/^#{characters}/)
  end
end
