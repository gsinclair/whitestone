require 'dev-utils/debug'   # During development only.
require 'stringio'
gem 'term-ansicolor', '1.0.5'
require 'term/ansicolor'
class String; include Term::ANSIColor; end

class String
  def ___indent(n)
    if n >= 0
      gsub(/^/, ' ' * n)
    else
      gsub(/^ {0,#{-n}}/, "")
    end
  end
  def ___truncate(n)
    str = self
    if str.length > n
      str[0...n] + "..."
    else
      str
    end
  end
end

module Attest
  class ErrorOccurred < StandardError; end
  class FailureOccurred < StandardError
    def initialize(context, message, backtrace)
      @context = context
      @message = message
      @backtrace = backtrace
    end
    attr_reader :context, :message, :backtrace
  end
  class AssertionSpecificationError < StandardError; end

  ##
  # A Test object is what results when the following code is executed:
  #   
  #   D "civil" do
  #     Eq @d.year,   1972
  #     Eq @d.month,  5
  #     Eq @d.day,    13
  #   end
  #
  # Test objects gather in a tree structure, useful for reporting.
  class Test
    attr_accessor :description, :block, :sandbox
    attr_accessor :result
    attr_accessor :error
    attr_accessor :parent
    attr_reader   :children
    def initialize(description, block, sandbox)
      @description, @block, @sandbox = description, block, sandbox
      @result = :pass   # Assume the test passes; if not, this will be updated.
      @error  = nil     # The exception object, if any.
      @parent = nil     # The test object in whose scope this test is defined.
      @children = []    # The children of this test.
    end
    def parent=(test)
      @parent = test
      if @parent
        @parent.children << self
      end
    end
    def passed?; @result == :pass;  end
    def failed?; @result == :fail;  end
    def error?;  @result == :error; end
  end

  ##
  # A Scope object contains a group of Test objects and the setup and teardown
  # information for that group.
  class Scope
    attr_reader :tests, :before_each, :after_each, :before_all, :after_all
    def initialize
      @tests       = []
      @before_each = []
      @after_each  = []
      @before_all  = []
      @after_all   = []
    end
  end

  class << Attest
    ##
    # Hash of pass, failure and error statistics.  Keys:
    #
    #   [:time]
    #     Number of seconds elapsed for test execution.
    #
    #   [:pass]
    #     Number of assertions that held true.
    #
    #   [:fail]
    #     Number of assertions that did not hold true.
    #
    #   [:error]
    #     Number of exceptions that were not rescued.
    #
    #   [:assertions]
    #     Number of assertions that were executed.
    #
    attr_reader :stats

    ##
    # The _description_ of the currently-running test.  Very useful for
    # conditional breakpoints in library code.  E.g.
    #   debugger if Attest.current_test =~ /something.../
    def current_test
      (@current_test.nil?) ? "(toplevel)" : @current_test.description
    end

    ##
    # When a C assertion is run (i.e. that the expected symbol will be thrown),
    # the value that is thrown along with the symbol will be stored in
    # Attest.caught_value in case it needs to be tested.  If no value is thrown,
    # this accessor will contain nil.
    attr_accessor :caught_value

    ##
    # When an E assertion is run (i.e. that the expected error will be raised),
    # the exception that is rescued will be stored in Attest.exception in case
    # it needs to be tested.
    attr_accessor :exception

    ##
    # Defines a new test composed of the given
    # description and the given block to execute.
    #
    # This test may contain nested tests.
    #
    # Tests at the outer-most level are automatically
    # insulated from the top-level Ruby environment.
    def D *description, &block
      create_test @tests.empty?, *description, &block
    end

    ##
    # Defines a new test that is explicitly insulated from the tests
    # that contain it and also from the top-level Ruby environment.
    #
    # This test may contain nested tests.
    def D! *description, &block
      create_test true, *description, &block
    end

    def create_test insulate, *description, &block
      raise ArgumentError, 'block must be given' unless block
      description = description.join(' ')
      sandbox = Object.new if insulate
      new_test = Attest::Test.new(description, block, sandbox)
      new_test.parent = @tests.last
      @current_scope.tests << new_test
    end
    private :create_test

    # Registers the given block to be executed
    # before each nested test inside this test.
    def <(*args, &block)
      if args.empty?
        raise ArgumentError, 'block must be given' unless block
        @current_scope.before_each << block
      else
        # the < method is being used as a check for inheritance
        super
      end
    end

    # Registers the given block to be executed
    # after each nested test inside this test.
    def > &block
      raise ArgumentError, 'block must be given' unless block
      @current_scope.after_each << block
    end

    # Registers the given block to be executed
    # before all nested tests inside this test.
    def << &block
      raise ArgumentError, 'block must be given' unless block
      @current_scope.before_all << block
    end

    # Registers the given block to be executed
    # after all nested tests inside this test.
    def >> &block
      raise ArgumentError, 'block must be given' unless block
      @current_scope.after_all << block
    end

    #
    # Here we define the methods T, F, N, Eq, Mt and their cousins T! and T?
    # etc.  The code is generated and routed through the 'action' method that
    # handles the general case of running a test.
    #

    require 'attest/assertion_classes'
      # ^^^ Assertion::True, Assertion::False, Assertion::Equality, etc.

    %w{T F N Eq Mt Ko Ft E C}.each do |base|
      assert_method = base
      negate_method = base + "!"
      query_method  = base + "?"

      lineno = __LINE__
      code = %{
        def #{assert_method}(*args, &block)
          action :#{base}, :assert, *args, &block
        end

        def #{negate_method}(*args, &block)
          action :#{base}, :negate, *args, &block
        end

        def #{query_method}(*args, &block)
          action :#{base}, :query, *args, &block
        end
      }
      module_eval code, __FILE__, lineno+2
    end

    # === Attest.action
    #
    # This is an absolutely key method.  It implements T, F, Eq, T!, F?, Eq?, etc.
    # After some sanity checking, it creates an assertion object, runs it, and
    # sees whether it passed or failed.
    #
    # If the assertion fails, we raise FailureOccurred, with the necessary
    # information about the failure.  If an error happens while the assertion is
    # run, we don't catch it.  Both the error and the failure are handled
    # upstream, in Attest.call.
    #
    # It's worth noting that errors can occur while tests are run that are
    # unconnected to this method.  Consider these two examples:
    #       T { "foo".frobnosticate? }     -- error occurs on our watch
    #       T "foo".frobnosticate?         -- error occurs before T() is called
    #
    # By letting errors from here escape, the two cases can be dealt with
    # together.
    #
    # T and F are special cases: they can be called with custom assertions.
    #
    #   T :circle, c, [4,1, 10, :H]
    #     -> run_custom_test(:circle, :assert, [4,1,10,:H])
    #
    def action(base, assert_negate_query, *args, &block)
      mode = assert_negate_query    # :assert, :negate or :query

      @assertion_classes ||= {
        :T =>  Assertion::True,      :F =>  Assertion::False,  :N => Assertion::Nil,
        :Eq => Assertion::Equality,  :Mt => Assertion::Match,  :Ko => Assertion::KindOf,
        :Ft => Assertion::FloatEqual,:E =>  Assertion::ExpectError, :C => Assertion::Catch,
        :custom => Assertion::Custom
      }

      # Sanity checks: these should never fail!
      unless [:assert, :negate, :query].include? mode
        raise AssertionSpecificationError, "Invalid mode: #{mode.inspect}"
      end
      unless @assertion_classes.key? base
        raise AssertionSpecificationError, "Invalid base: #{base.inspect}"
      end

      # Special case: T may be used to invoke custom assertions.
      # We catch the use of F as well, even though it's disallowed, so that
      # we can give an appropriate error message.
      if base == :T or base == :F and args.size > 1 and args.first.is_a? Symbol
        if base == :T and mode == :assert
          ### name = args.shift
          ### return run_custom_test(name, mode, *args, &block)
          # Run a custom assertion.
          inside_custom_assertion do
            action(:custom, :assert, *args)
          end
          return nil
        else
          message =  "You are attempting to run a custom assertion.\n"
          message << "These can only be run with T, not F, T?, T!, F? etc."
          raise AssertionSpecificationError, message
        end
      end

      assertion = @assertion_classes[base].new(mode, *args, &block)
        # e.g. assertion = Assertion::Equality(:assert, 4, 4)   # no block
        #      assertion = Assertion::Nil(:query) { names.find "Tobias" }
        #      assertion = Assertion::Custom(...)

      # For now we assume there's no error, so result is 'true' or 'false' (for
      # pass or fail).  We negate it if necessary and report the failure if
      # necessary.

      stats[:assertions] += 1 unless @inside_custom_assertion
      passed = assertion.run   # Returns true or false for pass or failure,
                               # or of course an error may be raised.
      case mode
      when :negate then passed = ! passed
      when :query  then return passed
      end
      if not passed
        calling_context = assertion.block || @calls.last
        backtrace = caller
        raise FailureOccurred.new(calling_context, assertion.message, backtrace)
      end
      nil
    end  # action
    private :action

    ##
    # {inside_custom_assertion} allows us (via {yield}) to run a custom
    # assertion without racking up the assertion count for each of the
    # assertions therein.
    # TODO: consider making it a stack so that custom assertions can be nested.
    def inside_custom_assertion
      @inside_custom_assertion = true
      stats[:assertions] += 1
      yield
    ensure
      @inside_custom_assertion = false
    end


    # Mechanism for sharing code between tests.
    #
    # If a block is given, it is shared under the given identifier.  Otherwise,
    # the code block that was previously shared under the given identifier is
    # injected into the closest insulated Attest test that contains the call to
    # this method.
    #
    #   S :values do
    #     @values = [8,9,10]
    #   end
    #
    #   D "some test" do
    #     S :values
    #     Eq @values.last, 10
    #   end
    #
    #   D "another test" do
    #     S :values
    #     Eq @values.length, 3
    #   end
    #
    def S identifier, &block
      if block_given?
        if already_shared = @share[identifier]
          raise ArgumentError, "A code block #{already_shared.inspect} has already been shared under the identifier #{identifier.inspect}."
        end

        @share[identifier] = block

      elsif block = @share[identifier]
        if @tests.empty?
          raise "Cannot inject code block #{block.inspect} shared under identifier #{identifier.inspect} outside of a Attest test."
        else
          # find the closest insulated parent test; this should always
          # succeed because root-level tests are insulated by default
          test = @tests.reverse.find {|t| t.sandbox }
          test.sandbox.instance_eval(&block)
        end

      else
        raise ArgumentError, "No code block is shared under identifier #{identifier.inspect}."
      end
    end

    # Shares the given code block under the given identifier and then
    # immediately injects that code block into the closest insulated Attest test
    # that contains the call to this method.
    #
    #   D "some test" do
    #     S! :example do
    #       @string = "Hello, world!"
    #     end
    #     Mt /[.,"'!?]/, @string
    #   end
    #
    #   D "another test" do
    #     S :example
    #     N @string.find "Z"
    #   end
    #
    def S! identifier, &block
      raise 'block must be given' unless block_given?
      S identifier, &block
      S identifier
    end

    # Checks whether any code has been shared under the given identifier.
    def S? identifier
      @share.key? identifier
    end

    #
    # === Attest.run
    #
    # Executes all tests defined thus far.  Tests are defined by 'D' blocks.
    # Test objects live in a Scope.  @current_scope is the top-level scope, but
    # this variable is changed during execution to point to nested scopes as
    # needed (and then changed back again).
    #
    # This method should therefore be run _after_ all the tests have been
    # defined, e.g. in an at_exit clause.  Requiring 'attest/auto' does that for
    # you.
    #
    def run
      # Clear previous results.
      @stats.clear
      @tests.clear

      # Execute the tests.
      @stats[:time] = time do
        catch(:stop_dfect_execution) do
          execute       # <-- This is where the real action takes place.
        end
      end

      # Display reports.
      @output.display_test_by_test_result(@top_level)
      @output.display_details_of_failures_and_errors
      @output.display_results_npass_nfail_nerror_etc(@stats)

      @current_scope = Attest::Scope.new
      # ^^^ In case 'run' gets called again; we don't want to re-run the old tests.
    end

    # Stops the execution of the {Attest.run} method or raises
    # an exception if that method is not currently executing.
    def stop
      throw :stop_dfect_execution
    end

    private

    # Record the elapsed time to execute the given block.
    def time
      start = Time.now
      yield
      finish = Time.now
      finish - start
    end

    # === Attest.execute
    #
    # Executes the current test scope recursively.  A SCOPE is a collection of D
    # blocks, and the contents of each D block is a TEST, comprising a
    # description and a block of code.  Because a test block may contain D
    # statements within it, when a test block is run @current_scope is set to
    # Scope.new so that newly-encountered tests can be added to it.  That scope
    # is then executed recursively.  The invariant is this: @current_scope is
    # the CURRENT scope to which tests may be added.  At the end of 'execute',
    # @current_scope is restored to its previous value.
    #
    # The per-test guts of this method have been extracted to {execute_test} so
    # that the structure of {execute} is easier to see.  {execute_test} contains
    # lots of exception handling and comments.
    def execute
      @current_scope.before_all.each {|b| call b }     # Run pre-test setup
      @current_scope.tests.each do |test|              # Loop through tests
        @current_scope.before_each.each {|b| call b }  # Run per-test setup
        @tests.push test; @current_test = test

        execute_test(test)                             # Run the test

        @tests.pop; @current_test = @tests.last
        @current_scope.after_each.each {|b| call b }   # Run per-test teardown
      end
      @current_scope.after_all.each {|b| call b }      # Run post-test teardown
    end

    # === Attest.execute_test
    #
    # Executes a single test (block containing assertions).  That wouldn't be so
    # hard, except that there could be new tests defined within that block, so
    # we need to create a new scope into which such tests may be placed [in
    # {create_test} -- {@current_scope.tests << Test.new(...)}].
    #
    # The old scope is restored at the end of the method.
    #
    # The new scope is executed recursively in order to run any tests created
    # therein.
    #
    # Exception (and failure) handling is straightforward here.  The hard work
    # is done in {call}; we just catch them and do nothing.  The point is to
    # avoid the recursive {execute}: fail fast.
    #
    def execute_test(test)
      stored_scope = @current_scope
      begin
        # Create nested scope in case a 'D' is encountered while running the test.
        @current_scope = Attest::Scope.new

        # Run the test block, which may create new tests along the way (if the
        # block includes any calls to 'D').
        call test.block, test.sandbox
        @stats[:pass] += 1
        @current_test.result = :pass

        # Execute the nested scope.  Nothing will happen if there are no tests
        # in the nested scope because before_all, tests and after_all will be
        # empty.
        execute

      rescue FailureOccurred => f
        # See method-level comment regarding exception handling.
        :noop
      rescue ErrorOccurred => e
        :noop
      rescue Exception => e
        # We absolutely should not be receiving an exception here.  Exceptions
        # are caught up the line, dealt with, and ErrorOccurred is raised.  If
        # we get here, something is strange and we should exit.
        STDERR.puts "Internal error: #{__FILE__}:#{__LINE__}; exiting"
        puts e.inspect
        puts e.backtrace
        exit!
      ensure
        # Restore the previous values of @current_scope
        @current_scope = stored_scope
      end
    end  # execute_test


    # === Attest.call
    #
    # Invokes the given block and debugs any exceptions that may arise as a result.
    # The block can be from a Test object or a "before-each"-style block.
    #
    # If an assertion fails or an error occurs during the running of a test, it
    # is dealt with in this method (update the stats, update the test object,
    # re-raise so the upstream method {execute} can abort the current test/scope.
    #
    def call block, sandbox = nil
      begin
        @calls.push block

        if sandbox
          sandbox.instance_eval(&block)
        else
          block.call
        end

      rescue AssertionSpecificationError => e
        ## An assertion has not been properly specified.  This is a special kind
        ## of error: we report it and exit the process.
        ### @output.report_specification_error e
        ### exit!
        # I've changed my mind.  If a single assertion is incorrectly specified,
        # all that should happen is that the test its in should error out.  The
        # rest of the tests can keep going.
        @stats[:error] += 1
        @current_test.result = :error
        @current_test.error  = e
        @output.report_uncaught_exception( current_test, e, @calls, :filter )
        raise ErrorOccurred
        # If this approach works, it can be combined with Exception below,
        # rather than duplicating the code.

      rescue FailureOccurred => f
        ## A failure has occurred while running a test.  We report the failure
        ## and re-raise the exception so that the calling code knows not to
        ## continue with this test.
        @stats[:fail] += 1
        @current_test.result = :fail
        @output.report_failure( current_test, f.message, f.backtrace )
        raise

      rescue Exception => e
        ## An error has occurred while running a test.  We report the error and
        ## then raise Attest::ErrorOccurred so that the code running the test
        ## knows an error occurred.  It doesn't need to do anything with the
        ## error; it's just a signal.
        @stats[:error] += 1
        @current_test.result = :error
        @current_test.error  = e
        @output.report_uncaught_exception( current_test, e, @calls )
        raise ErrorOccurred

      ensure
        @calls.pop
      end
    end  # call


  end  # class << Attest

  @stats  = Hash.new { |h,k| h[k] = 0 }

  @top_level = Attest::Scope.new
                         # We maintain a handle on the top-level scope so we can
                         #   walk the tree and produce a report.
  @current_scope = @top_level
                         # The current scope in which tests are defined.  Scopes
                         #   nest; this is handled by saving and restoring state
                         #   in the recursive method 'execute'.
  @tests = []            # Stack of the current tests in scope (as opposed to a list
                         #   of the tests in the current scope).
  @current_test  = nil   # Should be equal to @tests.last.
  @share = {}
  @calls = []            # Stack of blocks that are executed, allowing access to
                         #   the outer context for error reporting.
  require 'attest/output'
  @output = Output.new   # Handles output of reports to the console.

  # Allows before and after hooks to be specified via the
  # following method syntax when this module is mixed-in:
  #
  #   D .<< { puts "before all nested tests" }
  #   D .<  { puts "before each nested test" }
  #   D .>  { puts "after  each nested test" }
  #   D .>> { puts "after  all nested tests" }
  #
  D = ::Attest

  # Provide mixin-able assertion methods.  These are defined in the module
  # Attest (instead of being directly executable methods like Attest.Eq) and as
  # such can be mixed in to the top level with an `include Attest`.
  methods(false).grep(/^(x?[A-Z][a-z]?)?[<>!?]*$/).each do |name|
    #
    # XXX: using eval() on a string because Ruby 1.8's
    #      define_method() cannot take a block parameter
    #
    module_eval "def #{name}(*a, &b) ::#{self.name}.#{name}(*a, &b) end",
      __FILE__, __LINE__
    unless name =~ /[<>]/
      # Also define 'x' method that is a no-op; e.g. xD, xT, ...
      module_eval "def x#{name}(*a, &b) :no_op end", __FILE__, __LINE__
      module_eval "def Attest.x#{name}(*a, &b) :no_op end", __FILE__, __LINE__
    end
  end

end  # module Attest


# --------------------------------------------------------------------------- #
#
#                       C u s t o m   A s s e r t i o n s
#
# --------------------------------------------------------------------------- #
#
#  This code is being worked on and will be moved to an appropriate place
#  in due course.

gem 'facets'
require 'facets/string/margin'   # TODO: perhaps implement it myself -- it's not
                                 # ideal for a test framework to be adding stuff
                                 # to String (consider colours as well!)
require 'pp'

##
# Attest.custom _defines_ a custom assertion.
#
# Example usage:
#   Attest.custom :circle, {
#     :description => "Circle equality",
#     :parameters  => [ [:circle, Circle], [:values, Array] ],
#     :run => lambda { |circle, values|
#       x, y, r, label = values
#       test('x')     { Ft x, circle.centre.x         }
#       test('y')     { Ft y, circle.centre.y         }
#       test('r')     { Ft r, circle.radius           }
#       test('label') { Eq Label[label], circle.label }
#     }
#   }
def Attest.custom(name, definition)
  define_custom_test(name, definition)
end

def Attest.define_custom_test(name, definition)
  unless Symbol === name and Hash === definition and
         definition.keys.to_set == Set[:description, :parameters, :run]
    message = %{
      #Usage: Attest.custom name, definition
      #  where name is a symbol
      #    and definition is a hash with keys :description, :parameters, :run
    }.margin
    raise AssertionSpecificationError, usage
  end
  debug "Attest.define_custom_test:".yellow.bold
  debug "  name: #{name.inspect}"
  debug "  definition: #{definition.pretty_inspect}"
  Assertion::Custom.define(name, definition)
end  # define_custom_test

# This should return true or false as 'action' needs to know if this test passed
# or failed.  If we catch a FailureOccurred, then, we return false.
###   def Attest.run_custom_test(name, mode, *args)
###     debug "Attest.run_custom_test:".yellow.bold
###     debug "  name: #{name.inspect}"
###     debug "  args: #{args.inspect}"
###     ###  assertion = Assertion::Custom.new(name, mode, *args)
###     ###    # name could be (for instance) :circle, :circle! or :circle?
###     ###    # create_instance needs to look out for that and set the 'mode' accordingly.
###     ###  assertion.run
###     ###    # ^^^ will return true or false; then what?
###     args.unshift name
###     inside_custom_assertion do
###       action(:custom, mode, *args)
###     end
###     true  # if we get here, we passed (I think)
###   rescue Assertion::Custom::CustomAssertionUndefined => e
###     # This is essentially an AssertionSpecificationError.
###     raise AssertionSpecificationError, e.message
###   ### rescue FailureOccurred => f
###   ###   debug "run_custom_test -- caught FailureOccurred".red.bold
###   ###   context = f.context
###   ###   message = assertion.message
###   ###   backtrace = caller
###   ###   raise FailureOccurred.new(context, message, backtrace)
###   ### rescue Exception => e
###   ###   # An exception occurred while running the assertion.  I hope it can be dealt
###   ###   # with up the chain.
###   ###   debug "run_custom_test -- caught Exception #{e.class}".red.bold
###   ###   debug e.message
###   ###   raise
###   rescue FailureOccurred => f
###     return false
###   end

