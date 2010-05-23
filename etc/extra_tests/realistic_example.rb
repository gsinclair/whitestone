
# This file contains a realistic example of unit testing using attest.  The
# code contains bugs which the tests reveal.

# - something with a complex #inspect and/or #to_s (or perhaps #html)
# - something that takes direct input and gives direct output
#   (i.e. no need for reading file or interacting with other objects)
# - something involving some parsing, like RGeom's types
# - something involving a data store (index), especially if it means
#   that setup is required before the tests
# - add_xxx(...)
# - maybe take a test from an existing project (RubyGems?) and convert
#   it to attest
# - RGeom::Label ?
# - RGeom::Point, modified to store points like :A itself ?
#   - and RGeom::Vertex to boot?
# - something that takes a nested data structure (arrays inside hashes
#   inside...) and generates meaningful summary data
# - look at existing unit testing tutorials on the net
#   - found nothing
# - something in standard library ?
#   - extend Date with some Duration-type methods ?
# - some extensions to core classes, taken from 'extensions' ?

  # p1 = Point.new(5, -2)
  # p2 = Point.polar(11, 30)
  # Point[:A] = p1
  # Point[:B] = p2
  # Point[:A]         # -> p1
class Point
  @@index = Hash.new
  def initialize(x, y)
    @x, @y = x, y
  end
  def Point.cartesian(x, y)
    Point.new(x, y)
  end
  def Point.polar(r, th)
    Point.new(r * Math.cos(th), r * Math.sin(th))
  end
  def Point.[](symbol)
    @@index[symbol]
  end
  def Point.[]=(symbol, point)
    @@index[symbol] = point
  end
  def polar
    r = Math.sqrt(x**2 + y**2)
    th = Math.atan2(y, x)
    [r, th]
  end
end


# 
# Simple markup function to turn formatted text into HTML:
# * Implement _word_, *word* and @word@ (em, strong and code, respectively);
# * Surround paragraphs with <p> tags;
# * Turn single newlines into spaces.
# 
def simple_markup(string)
  tag = lambda { |str, t| "<#{t}>#{str}</#{t}>" }
  html = string.
    gsub(/_(\w+)_/)     { tag[$1, :em]     }.
    gsub(/\*(\W+)\*/)   { tag[$1, :strong] }.
    gsub(/@(\w+)@/)     { tag[$1, :code]   }.
    gsub(/(.+?)\n{2,}/) { tag[$1, :p]      }. 
    gsub(/\n/, ' ')
end

D "simple_markup" do
  D "breaks text into paragraphs" do
    Eq simple_markup("abc"),                     "<p>abc</p>"
    Eq simple_markup("abc\n\ndef"),              "<p>abc</p><p>def</p>"
    Eq simple_markup("abc\n\ndef\n\n\n\nghi\n"), "<p>abc</p><p>def</p><p>ghi</p>"
  end
  D "replaces single newlines with a space" do
    Eq simple_markup("abc\ndef"),      "<p>abc xyz</p>"
    Eq simple_markup("abc\ndef\nghi"), "<p>abc xyz ghi</p>"
  end
  D "handles mixed paragraphs and single newlines correctly" do
    text = "Once upon a time\nIn a land far away\n\n" \
         + "A frog named Kermit\n\nDecared he was here to stay"
    html = "<p>Once upon a time In a land far away</p>" \
         + "<p>A frog named Kermit Decared he was here to stay</p>"
    Eq simple_markup(text), html
  end
  D "handles _words_" do
    Eq simple_markup("One _two_ _three_"), "<p>One <em>two</em> <em>three</em></p>"
  end
  D "handles *words*" do
    Eq simple_markup("One *fine* day"), "<p>One <strong>fine</strong> day</p>"
  end
end
