D "Outer" do
  T { 1 + 1 == 2 }

  D "Inner" do
    F false
    N "foo".gsub!(/x/,'y')
  end
end

D "Fail fast on error (direct execution)" do
  T { 1 + 1 == 2 }             # will pass
  T "foo".frobnosticate?       # will cause error and should cause suite to aboure
  Eq "attest".length, 6        # would pass if it ran
  Eq "attest".length, 10       # would fail, but shouldn't get to this point

  D "Won't get here" do
    Eq "won't get here".size, 30   # shouldn't see a failure for this
  end
end

D "Fail fast on error (indirect execution)" do
  T { 1 + 1 == 2 }             # will pass
  T { "foo".frobnosticate? }   # will cause error and should cause suite to aboure
  T false                      # shouldn't see failure for this
end

# Not implemented at the time this code was committed.
D "Fail fast on assertion failure" do
  T { 1 + 1 == 2 }             # will pass
  Eq 5.succ, 8                 # will fail and thereby cause suite to abort
  Eq "attest".length, 6        # would pass if it ran
  Eq "attest".length, 10       # would fail, but shouldn't get to this point

  D "Won't get here" do
    Eq "won't get here".size, 30   # shouldn't see a failure for this
  end
end

D "Sibling suites unaffected by error or failure" do
  D "suite 1 pass" do
    T true
  end
  D "suite 2 fail" do
    T nil
  end
  D "suite 3 pass (unaffected by suite 2's failure)" do
    T true
  end
  D "suite 4 error" do
    T { "foo".frobnosticate? }
  end
  D "suite 5 pass (unaffected by suite 4's error)" do
    T true
  end
end

