
class String

  def ___indent(n)
    if n >= 0
      gsub(/^/, ' ' * n)
    else
      gsub(/^ {0,#{-n}}/, "")
    end
  end

  def ___truncate(n)
    str = self
    if str.length > n
      str[0...n] + "..."
    else
      str
    end
  end

  def ___margin  # adapted from 'facets' project
    d = ((/\A.*\n\s*(.)/.match(self)) ||
        (/\A\s*(.)/.match(self)))[1]
    return '' unless d
    gsub(/\n\s*\Z/,'').gsub(/^\s*[#{d}]/, '')
  end

end

