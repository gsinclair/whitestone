---
layout: default
title: Attest
---

# Attest -- a Ruby unit testing library

## Table of contents

* Overview
* Assertion methods: `T`, `F`, `Eq`, `Mt`, `Ko`, `Ft`, `E`, `C`
* Other methods: `D`, `S`, `<`, `<<`, `>>`, `>`, `run`, `stop`, `current_test`,
  `caught_value`, `xT`, `xF`, etc.
* `attest`, the test runner
* Motivation
* Differences from Dfect
* Credits
* Dependencies and requirements


## Overview

Attest saw its public release in July 2010 as an already-mature unit testing
library, being a derivative work of [Dfect][] v2.1.0.  Attest inherits dfect's
terse methods (D, F, E, C, T) and adds extra testing capabilities (nil,
equality, matches, kind_of, ...) and colourful output on the terminal.

It is worth examining the [Dfect][] documentation as all of its general
principles apply to Attest, and some of them will not be thoroughly documented
herein.

[Dfect]: http://snk.tuxfamily.org/lib/dfect/

### Benefits of Attest

* Terse testing methods that keeps the visual emphasis on your code.
* Nested tests with shared or individual setup and teardown code.
* Colourful output on the terminal that lubricates the cycle of code, test, fix.
* Clear report of which tests have passed and failed.
* An emphasis on informative failure and error messages.
  * For instance, when two long strings are expected to be equal but are not,
    the differences between them are colour-coded.
* The name of the current test is available to you for setting conditional
  breakpoints in the code you're testing.
* Very useful and configurable test runner (`attest`).

### Example of usage

Imagine you wrote the `Date` class in the Ruby standard library.  The following
Attest code could be used to test some of it.  All of these tests pass.

    require 'attest/include'                # Saves you from doing "include Attest"
    require 'date'
  
    D "Date" do
  
      D.< {                                 # setup for each block
        @d = Date.new(1972, 5, 13)
      }
  
      D "#to_s" do
        Eq @d.to_s, "1972-05-13"
      end
  
      D "#next" do
        end_of_april = Date.new(2010, 4, 30)
        start_of_may = Date.new(2010, 5, 1)
        T { end_of_april.next == start_of_may }
      end
  
      D "day, month, year, week, day-of-year, etc." do
  
        D.< { :extra_setup_for_these_three_blocks_if_required }
  
        D "civil" do
          Eq @d.year,   1972
          Eq @d.month,  5
          Eq @d.day,    13
        end
        D "commercial" do
          Eq @d.cwyear, 1972
          Eq @d.cweek,  19       # Commercial week-of-year
          Eq @d.cwday,  6        # Commercial day-of-week (6 = Sat)
        end
        D "ordinal" do
          Eq @d.yday,   134      # 134th day of the year
        end
      end
  
      D "#leap?" do
        [1984, 2000, 2400].each do |year|
          T { Date.new(year, 6, 27).leap? }
        end
        [1900, 2007, 2100, 2401].each do |year|
          F { Date.new(year, 12, 3).leap? }
        end
      end

      D "#succ creates new Date object" do
        Ko @d.succ, Date
      end
  
    end

### Example of output

![Equality assertion failure](http://tinyurl.com/22qop45 "Equality assertion failure")

This image shows the kind of output you can expect to see when an assertion
fails.  In white you see the name of the test.  The code surrounding the
assertion failure is shown, with the relevant line highlighted.  A clear message
is presented and the colour-coded actual and expected values help you see and
understand what's going on at a glance.

What's _not_ shown in this image:

* If the actual and expected values are long strings, an additional line will be
  printed using colour to show the _difference_ between them.
* After all tests are run, a colourful summary tells you the number of tests,
  passes, failures and errors.


## Assertion methods

    Method   Nmenomic    Definition, syopsis, examples

      T      True        Asserts condition or block has a "true" value
                             T { code... }
                             T value
                             T { person.age > 18 }
                             T connection.closed?

      F      False       Asserts condition or block has a "false" value
                             F { code... }
                             F value
                             F { date.leap }
                             F connection.open?

      N      Nil         Asserts condition or block is specifically nil
                             N { code... }
                             N value
                             N { string.index('a') }
                             N person.title

      Eq     Equals      Asserts an object is equal to its expected value
                             Eq OBJECT, VALUE
                             Eq person.name, "Theresa"

      Mt     Matches     Asserts a string matches a regular expression
                             Mt STRING, REGEX
                             Mt REGEX,  STRING
                             Mt "banana", /(an)+/
                             Mt /(an)+/,  "banana"

      Ko     KindOf      Asserts an object is kind_of? a certain class/module
                             Ko OBJECT,  CLASS
                             Ko "foo",   String
                             Ko (1..10), Enumerable

      Ft     Float       Asserts a float is "essentially" equal to its expected value
                             Ft FLOAT, FLOAT [, EPSILON]
                             Ft Math::PI, 3.14159265
                             Ft Math::PI, 3.14              # will fail
                             Ft Math::PI, 3.14, 0.1         # will pass
                         The comparison used is relative, not absolute.  The
                         difference divided by the expected value must be less
                         than 'epsilon' (default 0.000001).

      E      Exception   Asserts an exception is raised
                             E { code... }
                             E(Class1, Class2, ...) { code...}
                             E { "hello".frobnosticate }
                             E(NameError) { "hello".frobnosticate }

      C      Catches     Asserts the given symbol is thrown
                             C(symbol) { code... }
                             C(:done) { some_method(5, :deep) }

Notes:

* The order of arguments in `Eq OBJ, VALUE` is different from test/unit, where
  the expected value comes first.  To remember it, compare the following two
  lines.

      T { person.name == "Theresa" }
      Eq  person.name,   "Theresa"

  The same is true for `Ko OBJ, CLASS`:

      T { object.kind_of? String }
      Ko  object, String

* If you need to test the (possible) value that is thrown along with a symbol,
  you can use `Attest.caught_value`:

      D "Testing the object that is thrown" do
        array = [37, 42, 9, 105, 99, -1]
        C(:found) { search array, :greater_than => 100 }
        Eq Attest.caught_value, 105
      end

  The method `Attest.caught_value` will return the most recent caught value, but
  only those values caught in the process of running a `C` assertion.  If no
  value was thrown with the symbol, it will be `nil`.

### Negative assertions and queries

Each assertion method has three _modes_: assert, negate and query.  Best
demonstrated by example:

    string = "foobar"
    Eq  string.upcase, "FOOBAR"          # assert
    Eq! string.length, 10                # negate
    Eq? string.length, 10                # query -- returns true or false
                                         #          (doesn't assert anything)

For completeness, all of the negative assertion methods are briefly described
below.

    Method    Asserts that...
    T!        ...the condition/block does NOT have a true value
    F!        ...the condition/block does NOT have a false value
    N!        ...the condition/block is NOT nil
    Eq!       ...the object is NOT equal to the given value
    Mt!       ...the string does NOT match the regular expression
    Ko!       ...the object is NOT an instance of the given class/module
    Ft!       ...the float value is NOT "essentially" equal to the expected value
    E!        ...the code in the block does NOT raise an exception
                 (specific exceptions may be specified)
    C!        ...the code in the block does NOT throw the given symbol

Obviously there is not much use to `T!` and `F!`, but the rest are very
important.

Again for completeness, here is a list of the query methods:

    T?  F?  N?  Eq?  Mt?  Ko?  Ft?  E?  C?

`E?` takes optional arguments: the Exception classes to query.  `C?`, like `C`
and `C!`, takes a mandatory argument: the symbol that is expected to be thrown.


## Other methods

Briefly:
* **D** introduces a test, _describing_ it.
* **S** shares data between test blocks.
* `<` and `>` do setup and teardown for each test block in the current scope.
* `<<` and `>>` do global setup and teardown for the current scope.
* `xD`, `xT`, `xF`, `xEq`, `xMt`, `xKo`, `xE` and `xC` are no-op methods that
  enable you to neutralise an assertion or a test.
* `Attest.run` runs the currently-loaded test suite; `Attest.stop` aborts it.
  If you use `require "attest/auto"` or the `attest` test runner, you don't need
  to start the tests yourself.
* `Attest.current_test` is the name of the currently-running test.
* `Attest.caught_value` is the most recent value caught in a `C` assertion (see
  above).
* `Attest.stats` is a hash containing the number of passes, failures, and
  errors, and the total time taken to run the tests.

### Describing tests: D and D!

**D** is used to introduce a test.  Tests can be nested.  If you use **D!**
instead, the test will run in an _insulated_ environment: instance variables
from outer blocks will not be visible, and you can include modules and define
methods without side-effects outside the block.

Top-level tests are always insulated.

### Sharing code: S, S! and S?

**S** is used to share code between tests.  When called with a block, it stores
the code with the given identifier.  When called without the block, it injects
the appropriate block into the current environment.

    S :data1 do
      @text = "I must go down to the seas again..." }
    end

    D "Length" do
      S :data1
      T { @text.length > 10 }
    end

    D "Regex" do
      S :data1
      Mt /again/, @text
    end
    
**S!** combines the two uses of **S**: it simultaneously shares the block while
injecting it into the current environment.

Finally, **S?** is simply a query to ascertain whether a certain block is shared
in the current scope.

    S :data2 do
      @text = "Once upon a midnight dreary, while I pondered weak and weary..."
    end

    D! "Insulated test" do
      S :data2
      S? :data2      # -> true
      S? :data1      # -> false
    end
    
### Setup and teardown hooks

    D "outer test" do
      D.<  { puts "before each nested test -- e.g. prepare some data" }
      D.>  { puts "after  each nested test -- e.g. close a file" }

      D.<< { puts "before all nested tests -- e.g. create a database connection" }
      D.>> { puts "after  all nested tests -- e.g. close a database connection" }

      D "inner test 1" do
        # assertions and logic here
      end

      D "inner test 2" do
        D.< { :setup_relevant_to_inner_test_2 }
        # ...
      end

      # and so on
    end

The hooks are easy to use and remember.  However, note that they are not
top-level methods like `D()`, `T()`, `Eq()` etc.  They are module methods in the
`Attest` module, which is aliases to `D` via the code `D = Attest` to enable the
convenient usage above.

### The name of the currently-running test

`Attest.current_test` is the name of the currently-running test.  This allows
you to set useful conditional breakpoints deep within the library code that you
are testing.  Here's an example scenario:

    def paragraphs
      result = []
      paragraph = []
      loop do
        if eof?
          # ...
        elsif current_line.empty?
          if paragraph.empty?
            debugger if Attest.current_test =~ /test1/

This method is called often during the course of tests, but something is failing
during a particular test and I want to debug it.  If I start the debugger in the
_test_ code, then I need to step through a lot of code to reach the problem
area.  Using `Attest.current_test`, I can start the debugger close to where the
problem actually is.

## `attest`, the test runner

If you work in a project directory with your test files in a directory like
`test` or `spec` and your library files in `lib`, then this test runner is for
you.

If you want to restrict a test run to those test files matching a certain
pattern, then this test runner is for you.

If you want to keep your test code free of `require` statements, then this test
runner is for you.  (Put them in `test/_setup.rb`, which will be auto-loaded.)

If you occasionally want to run a specific test file that's not in the normal
test directory with all the others, then this test runner is for you.

From the help output (`attest -h`):

    Usage:
    
      attest                 (run all test files...)
      attest topic           (...whose path contains 'topic')
    
      attest --list          (list the test files)
      attest --example 2     (run example #2)
      attest --test spec     (run tests from the 'spec' directory, not 'test')
      attest -t spec widget  (as above, but only filenames containing 'widget')
      attest -f etc/a.rb     (just run the one file; full path required)
  
    Formal options:
    
    Commands
          --example n                  Run example 'n' (1..5)
      -f, --file file                  Run the specified file only
                                         (_setup.rb won't be run)
      -l, --list                       List the available test files and exit
    
    Modifiers
      -I d1,d2,...                     Add d1,d2,... to library path
                                         instead of 'lib'
      -t, --test dir                   Specify the test directory
          --no-include                 Don't add any directory to library path
    
    Running options
      -s, --separate                   Run each test file separately
    
    Miscellaneous
      -v                               Verbose
      -h, --help


## Motivation

Having used `test/unit` for a long time I was outgrowing it but failing to warm
to other approaches, although I probably hadn't given them much of a chance.
The world seemed to be moving towards "specs", but I preferred, and still
prefer, the unit testing model: create objects with various inputs, then assert
that they satisfy various predicates.  To me, it's about state, not behaviour.

In October 2009 I made a list of features I wanted to see.  Here is an edited
quote from a blog post:

> I've given some thought to features of my own testing framework, should it ever
> eventuate:
> 
> * Simple approach, like test/unit (but also look at dfect and testy).
> * Less typing than test/unit.
> * Colourful output, drawing the eye to appropriate filenames and line numbers.
> * Stacktraces are filtered to get rid of rubbish like RubyGems's
>   "custom_require" (I do this already with my mods to turn).
> * Easy to select the test cases you want to run.
> * Output like turn \[a gem that modifies the output of `test/unit`].
> * Optional drop-in to debugger or IRB at point of failure.
> * Green for expected value, red for actual value.
> * Code-based filter of test(s) to be run.
> 
> I'm hoping not to create a testing framework anytime soon, but am saving this
> list here in case I want to do so in the future.

Months later, working on a new project, I finally bit the bullet.  Dfect met
many of the goals, and I liked it and it started tinkering with it.  My goals
now don't match that list precisely, but it was a good start.

## Differences from Dfect (v2.1.0)

If an error occurs while running an assertion's block, Attest considers it an
ERROR only, whereas Dfect will report a FAIL in addition.

Any error or failure will abort the current test (and any nested tests).  It is
fail-fast; Dfect continues to run assertions after an error or failure.

Attest has removed the "trace" feature from Dfect (a hierarchical structure
reporting on the result of each test, and containing logging statements from the
**L** method).  Consequently:
* Attest does not have the **L** method
* Attest does not have the `report` method (it has `stats` instead)

Attest does not offer to drop into a debugger or IRB at the point of failure.  I
prefer to use the `ruby-debug` gem and set breakpoints using `Attest.current_test`.

## Credits

Thanks to Suraj N. Kurapati, who created [Dfect][] and permitted me (explicitly
in response to a request and implicitly by its licence) to create and publish
this derivative work.  Dfect is a wonderful library; I just wanted to add some
assertions and tune the terminal output.  Several bits of code and prose have
made their way from Dfect's manual into this one, too.

## Dependencies and requirements

Dependencies (automatically resolved by RubyGems):
* `term/ansicolor` for coloured console output
* `differ` for highlighting difference between strings

Attest was developed using the following version of Ruby.  I have no knowledge
of whether it works in other environments.  My attempts to install Ruby 1.9 in
Cygwin have come to nought.

  ruby 1.8.7 (2008-08-11 patchlevel 72) [i386-cygwin]

The colours used in the console output were designed for a black background.
They are hardcoded and it would be a major effort to customise them!
