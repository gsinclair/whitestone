
# Used to test 'catch'
def even_or_odd(n)
  if n % 2 == 1
    throw :odd
  else
    throw :even
  end
end

# Used to generate errors (file not found).
def count_lines_in_file(path)
  File.readlines(path).size
end

# Used for assertions and error raising.
def prime?(n)
  unless (1..100).include? n
    raise ArgumentError, "Argument to prime? must be in range (1..100): #{n}"
  end
  unless Integer === n
    raise ArgumentError, "Argument to prime? must be an integer: #{n}"
  end
  return false if n == 1
  (2..Math.sqrt(n).to_i).map { |i| n % i }.all? { |rem| rem != 0 }
end

  # Used to test string equality and demonstrate string difference.
  # Surround with <p>, implement _word_, *word* and @word@.  Remove newlines.
def simple_html(string)
  tag = lambda { |str, t| "<#{t}>#{str}</#{t}>" }
  html = string.
    gsub(/_(\w+)_/)   { tag[$1, :em]     }.
    gsub(/\*(\w+)\*/) { tag[$1, :strong] }.
    gsub(/@(\w+)@/)   { tag[$1, :code]   }.
    gsub(/\r?\n/, ' ')
  tag[html, :p]
end
