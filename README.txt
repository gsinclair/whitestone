Attest is a unit-testing library, a derivative work of Suraj N. Karaputi's
"dfect" (http://snk.tuxfamily.org/lib/dfect), v2.1 (called "detest" as of v3.0).

Key features:
 * terse assertion methods
 * arbitrarily nested tests
 * colorful and informative console output
 * custom assertions
 * an excellent test runner

Example of test code, demonstrating many assertions:

  D "Person" do
    # setup code run just once
    D.<< { Person.initialize_tfn_lookup }

    # setup code run for each test at this level
    D.< { @p = Person.new("John", "Smith", 49) }

    D "basic methods" do
      Eq @p.first_name, "John"
      Eq @p.last_name,  "Smith"
      Eq @p.age, 49
    end

    D "graceful error message if badly initialized" do
      E(Person::Error) { Person.new(1, 2, 3) }
      Mt Attest.exception.message, /invalid first name: 1/
    end

    D "equality" do
      copy = @p.dup
      T { copy == @p }
      Eq copy, @p        # equivalent to above line
    end

    D "interactions with system" do
      D "tax file number is nil until set" do
        N @p.tfn
        F { @p.instance_variable_get :resolved_tfn }
        @p.resolve_tfn
        T { @p.instance_variable_get :resolved_tfn }
        Mt @p.tfn, /\d\d\d-\d\d\d-\d\d\d/
      end

      D "address lookup is cached" do
        a1 = @p.address
        a2 = @p.address
        Id a1, a2           # identical
        Ko a1, Address
      end
    end

  end  # "Person"

The assertion methods demonstrated were:

  T  -- assert true
  F  -- assert false
  N  -- assert object is nil
  Eq -- assert two objects equal
  Mt -- assert string matches regular expression
  Id -- assert two objects identical (same object)
  E  -- assert error is raised
  Ko -- assert an object is kind_of a class/module

Other assertion methods:

  Ft -- assert two floats are essentially equal
  C  -- assert object is thrown

All assertions can be negated by appending an exclamation mark.

See http://gsinclair.github.com/attest.html for full details (and screenshots).

