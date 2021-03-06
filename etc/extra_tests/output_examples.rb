
# The examples here are designed to demonstrate that all the different ways of
# failing (T, F, N, Eq, Mt, E, C) produce good output.
#
# Some of the tests will pass; some will fail; some will raise an error.
#
# The output doesn't make pretty reading, but it's a way to look for poor
# formatting or inconsistent colour or less-than-helpful error messages.

load "#{Dir.pwd}/etc/extra_tests/output_examples_code.rb"

D 'Vanilla assertion failure' do
  T { prime? 64 }
end

D "Attempt to open file that doesn't exist" do
  T { count_lines_in_file("fdsjhfaksljdfhakljshdf.txt") == 492 }
end

D 'Expected error to be raised but it didn\'t happen (default: StandardError)' do
  E { prime? 13 }
end

D "Expected error to be raised but it didn't happen (specify errors)" do
  E(ArgumentError, NameError) { prime? 99 }
end

D "Expect NameError to be raised but it's not NameError; it's Errno::ENOENT" do
  E(NameError) { count_lines_in_file("fdsjhfakslljshdf.txt") }
end

D 'Expect no error to occur, but one does' do
  E! { count_lines_in_file("fdsjhfaksljdfhakljshdf.txt") }
end

D 'Failure to catch appropriate symbol' do
  C(:something) { Dir.entries('.') }
end

D 'Expected :even not to be thrown but it was' do
  C!(:even) { even_or_odd(12) }
end

D 'Error raised while trying to catch a symbol' do
  C(:foo) { count_lines_in_file("fdsjhfakshakljshdf.txt") }
end

D 'Test prime?' do
  T { prime? 43 }
  F { prime? 1 }
  E { prime? 450 }
  E { prime? 41.9 }
  E!{ prime? 35 }
end

D 'Test even_or_odd' do
  C(:even) { even_or_odd(148) }
  C(:odd)  { even_or_odd(9313) }
end

D 'Straightforward equality failure (positive)' do
  array = (1...10).to_a
  Eq array.size, 10
end

D 'Straightforward equality failure (negative)' do
  Eq! "\n\t text   \r \n".strip, "text"
end

D 'Test simple_html; demonstrates string difference' do
  text = "I _must_ go down to the *seas* again\nTo the @lonely@ sea and the sky"
  Eq simple_html(text), 
    "<p>I <em>must</em> go down to <strong>seas</strong> again\nTo the " +
    "<code>lonely</code> sea and the skies</p>"
end

D 'Regular expression matching (positive)' do
  Mt "Smith, John: (02) 9481 1111", /^[A-z0-9]+$/
end

D 'Regular expression matching (negative)' do
  Mt! "Doe, Jane: (07) 131 008", /Jane/
end

D 'Expecting something to be nil' do
  N [25, 32, 7, 51].find { |n| prime? n }
end

D 'Expecting something not to be nil' do
  N! { "foo".index('t') }
end

D 'Identity (positive)' do
  Id "foo", "foo"
end

D 'Identity (negative)' do
  array = (1..10).to_a
  Id! array, array
end

D 'Float equality (positive)' do
  Ft 3.14, Math::PI
end

D 'Float equality (negative)' do
  Ft! 3.141592654, Math::PI
end
