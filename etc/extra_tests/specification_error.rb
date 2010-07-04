
D "Incorrect use of assertions" do
  T { 1 + 1 == 2 }     # this is fine
  T(5) { 6 }           # can't give argument _and_ block
  Eq 1, 2, 3           # must be two values
  Eq 1                 # must be two values
  Eq() { :foo }        # block not allowed
end
