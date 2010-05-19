
def some_method(n)
  raise ArgumentError unless n > 0
  n
end

D "An error should not also fail" do
  ## The following call should result in ERROR and not an additional FAIL.
  ## (This is therefore not a unit test, really; it's designed to error out...)
  T { this_method_does_not_exist(:foo) }

  ## This test works
  Eq some_method(5), 5

  ## This test errors out
  Eq some_method(-5), -5
end
