
D "Attest.action" do
  T { Attest.action :Eq, :query, 4, 4 }
  T { Attest.action :T,  :query, :foo }
  T { Attest.action(:T,  :query) { :foo } }
end

def this_method_will_raise_an_error
  raise StandardError, "Sample error"
end

def this_one_wont
  :foo
end

def throws_foo
  throw :foo
end

def doesnt_throw_foo
  :noop
end

def specific_error(sym)
  case sym
  when :type  then raise TypeError
  when :run   then raise RuntimeError
  when :range then raise RangeError
  when :io    then raise IOError
  else             raise ArgumentError
  end
end

D "Basic tests" do
  x = 2 + 2
  T  { x == 4 }
  T! { x == 5 }
  F  { x == 5 }
  F! { x == 4 }
  N  { "foo".index("z") }
  N! { "foo".index("o") }
  Eq  x, 4
  Eq! x, 5
  Mt  /(an){2}/, "banana"
  Mt! /(an){3}/, "banana"
  E  { this_method_will_raise_an_error }
  E! { this_one_wont }
  E!(RangeError) { this_one_wont }
  E()                      { specific_error(:run) }
  E(RuntimeError)          { specific_error(:run) }
  E(RuntimeError, IOError) { specific_error(:run) }
  C(:foo)  { throws_foo }
  C!(:foo) { doesnt_throw_foo }
end
