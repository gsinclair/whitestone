require 'date'

# In this test file, we create a simple Person class so that we have something
# to test custom assertions on.
#
# We implement CSV parsing to give a little realism to the scenario:
#  * we have a domain object (Person)
#  * we expect to create a lot of these in some way (CSV) and that these
#    objects will play a large part in our system
#  * we will therefore need to check the correctness of lots of these objects
#  * therefore, a custom assertion is handy

# Person consists of name (first, middle, last) and date of birth.
# Create them directly via Person.new(...) or indirectly by Person.from_csv "..."
class Person
  attr_accessor :first, :middle, :last
  attr_accessor :dob
  def initialize(f, m, l, dob)
    @first, @middle, @last, @dob = f, m, l, dob
  end
  # Reads multiple lines of CSV and returns an array of Person objects.
  def Person.from_csv(text)
    text.strip.split("\n").map { |line|
      f, m, l, dob = line.strip.split(",")
      m = nil if m.empty?
      dob = Date.parse(dob)
      Person.new(f,m,l,dob)
    }
  end
end

D "Custom assertions" do
  D "Create :person custom assertion" do
    E! do
      Whitestone.custom :person, {
        :description => "Person equality",
        :parameters => [ [:person, Person], [:string, String] ],
        :run => proc {
          f, m, l, dob = string.split
          m = nil if m == '-'
          dob = Date.parse(dob)
          test('first')  { Eq person.first,  f   }
          test('middle') { Eq person.middle, m   }
          test('last')   { Eq person.last,   l   }
          test('dob')    { Eq person.dob,    dob }
        }
      }
    end
  end

  D "Use :person custom assertion" do
    D.< do
      @people = Person.from_csv %{
        John,William,Smith,1974-03-19
        Jane,,Galois,1941-12-23
        Hans,Dieter,Flich,1963-11-01,
      }
    end

    D "manual check that people were created properly" do
      person = @people[1]
      Eq person.first, "Jane"
      N  person.middle
      Eq person.last, "Galois"
      Eq person.dob, Date.new(1941,12,23)
    end

    D "check all three people using :person custom assertion" do
      T :person, @people[0], 'John William Smith  1974-03-19'
      T :person, @people[1], 'Jane - Galois       1941-12-23'
      T :person, @people[2], 'Hans Dieter Flich   1963-11-01'
    end
  end

  D "correct message when a failure occurs" do
    @c = Term::ANSIColor
    D.< do
      @person = Person.new("Terrence", "James", "Hu", Date.new(1981,10,27))
    end
    D "in 'first' field" do
      # In testing this person object, we'll accidentally mispell the first name,
      # expect an error, and check that the message identifies the field ("first").
      E { T :person, @person, "Terence James Hu  1981-10-27" }
      Ko Whitestone.exception, Whitestone::FailureOccurred
      message = @c.uncolored(Whitestone.exception.message)
      Mt message, /Person equality test failed: first \(details below\)/
    end
    D "in 'middle' field" do
      E { T :person, @person, "Terrence Janes Hu  1981-10-27" }
      Ko Whitestone.exception, Whitestone::FailureOccurred
      message = @c.uncolored(Whitestone.exception.message)
      Mt message, /Person equality test failed: middle \(details below\)/
    end
    D "in 'last' field" do
      E { T :person, @person, "Terrence James Hux  1981-10-27" }
      Ko Whitestone.exception, Whitestone::FailureOccurred
      message = @c.uncolored(Whitestone.exception.message)
      Mt message, /Person equality test failed: last \(details below\)/
    end
    D "in 'dob' field" do
      E { T :person, @person, "Terrence James Hu  1993-02-28" }
      Ko Whitestone.exception, Whitestone::FailureOccurred
      message = @c.uncolored(Whitestone.exception.message)
      Mt message, /Person equality test failed: dob \(details below\)/
    end
  end

  D "check correct number of assertions" do
    # We are checking that the three 'T :person' assertions above only count as
    # three assertions, that their consituent primitive assertions are not added
    # to the total.
    person = Person.new("Henrietta", nil, "Evangalier", Date.parse('2002-04-09'))
    assertions = Whitestone.stats[:assertions]
    T :person, person, "Henrietta - Evangalier  2002-04-09"
    T :person, person, "Henrietta - Evangalier  2002-04-09"
    T :person, person, "Henrietta - Evangalier  2002-04-09"
    assertions = Whitestone.stats[:assertions] - assertions
    Eq assertions, 3
  end
end
