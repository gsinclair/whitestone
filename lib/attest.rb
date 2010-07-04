require 'dev-utils/debug'   # During development only.
require 'stringio'
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

# load interactive debugger
begin
  require 'ruby-debug'
rescue LoadError
  require 'irb'
end

module Attest
  class ErrorOccurred < StandardError; end
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
      debug "#{nested_space}create_test #{description}".yellow.bold
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

    %w{T F N Eq Mt Ko E C}.each do |base|
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

    ## The general method that implements T, F, Eq, T!, F?, Eq?, etc.
    def action(base, assert_negate_query, *args, &block)
      mode = assert_negate_query    # :assert, :negate or :query

      @assertion_classes ||= {
        :T =>  Assertion::True,      :F =>  Assertion::False,  :N => Assertion::Nil,
        :Eq => Assertion::Equality,  :Mt => Assertion::Match,  :Ko => Assertion::KindOf,
        :E =>  Assertion::Exception, :C =>  Assertion::Catch
      }

      unless [:assert, :negate, :query].include? mode
        raise AssertionSpecificationError, "Invalid mode: #{mode.inspect}"
      end
      unless @assertion_classes.key? base
        raise AssertionSpecificationError, "Invalid base: #{base.inspect}"
      end

      assertion = @assertion_classes[base].new(mode, *args, &block)
        # e.g. assertion = Assertion::Equality(:assert, 4, 4)   # no block
        #      assertion = Assertion::Nil(:query) { names.find "Tobias" }

      # For now we assume there's no error, so result is 'true' or 'false' (for
      # pass or fail).  We negate it if necessary and report the failure if
      # necessary.

      @symbols ||= { :assert => '', :negate => '!', :query => '?' }

      begin
        debug "#{nested_space}  #{base}#{@symbols[assert_negate_query]}".cyan.bold
        passed = assertion.run   # Returns true or false for pass or failure.
        case mode
        when :negate then passed = ! passed
        when :query  then return passed
        end
        # We are now into the "assertion" part of it: collecting stats and
        # printing a failure message if necessary.
        if passed
          @stats[:pass] += 1
        else
          @stats[:fail] += 1
          @current_test.result = :fail
          calling_context = assertion.block || @calls.last
          @output.report_failure calling_context, @current_test, assertion.message
            # TODO: consider making this possible
            #         report_failure assertion
            #       i.e. the assertion object contains the context and test.
          throw :abort_current_suite_due_to_failure
        end
      rescue => e
        # TODO: make this the (only) place where we do
        #   @stats[:error] += 1
        # (if possible)
        # UPDATE: I think it _is_ possible right now...
        @output.report_uncaught_exception @current_test.block, e, @current_test, @stats, @calls
        # Raise ErrorOccurred so that the calling code knows an error has
        # occurred and can skip the rest of the test.
        raise ErrorOccurred
      end
      passed
    end  # action

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
    #  ----------------------- Attest.run -----------------------
    #
    # Executes all tests defined thus far.  Tests are defined by 'D' blocks.
    # Test objects live in a Scope.  @current_scope is the top-level suite, but
    # this variable is changed during execution to point to nested suites as
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

    def nested_space
      "  " * @nested_level
    end

    # Record the elapsed time to execute the given block.
    def time
      start = Time.now
      yield
      finish = Time.now
      finish - start
    end

    # Executes the current test suite recursively.  A SUITE is a collection of D
    # blocks, and the contents of each D block is a TEST, comprising a
    # description and a block of code.  Because a test block may contain D
    # statements within it, when a test block is run @current_scope is set to
    # Scope.new so that newly-encountered tests can be added to it.  That suite
    # is then executed recursively.  The invariant is this: @current_scope is
    # the CURRENT suite to which tests may be added.  At the end of 'execute',
    # @current_scope is restored to its previous value.
    def execute
      stored_suite = current_suite = @current_scope
      @nested_level += 1
      current_suite.before_all.each {|b| call b }
      current_suite.tests.each do |test|
        current_suite.before_each.each {|b| call b }
        @tests.push test
        @current_test = test
        begin
          debug "#{nested_space}execute: #{current_test}".green.bold
          # Create nested suite in case a 'D' is encountered while running the
          # test -- this would cause 'create_test' to be called, which would run
          # code like @current_scope.tests << Test.new(...).
          @current_scope = Attest::Scope.new

          # Run the test block, which may create new tests along the way (if the
          # block includes any calls to 'D').
          run_test(test)

          # Execute the nested suite.  Nothing will happen if there are no tests
          # in the nested suite because before_all, tests and after_all will be
          # empty.
          execute
        rescue ErrorOccurred => e
          # By rescuing ErrorOccurred here, we prevent the nested 'execute'
          # above from running.  The error goes no further; the next action is
          # to go back to the outer suite and continue executing from there.
          @current_test.error = e
        ensure
          # Restore the previous values of @current_scope and @tests.
          @current_scope = stored_suite
          debug "#{nested_space}    --> #{@current_test.result} (#{current_test})"
        end
        @tests.pop
        @current_test = @tests.last
        current_suite.after_each.each {|b| call b }
      end   # loop through tests in current suite
      current_suite.after_all.each {|b| call b }
      @nested_level -= 1
    end  # execute

    def run_test(test)
      catch :abort_current_suite_due_to_failure do
        call test.block, test.sandbox
      end
    end

    # === Attest.call
    #
    # Invokes the given block and debugs any exceptions that may arise as a result.
    # The block can be from a Test object or a "before-each"-style block.
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
        @output.report_uncaught_exception block, e, @current_test, @stats, @calls
          ### ^^^^ Do we need this line?  We're exiting, right?  Do we need a
          ###      full report?  It's a hassle to do so because it's not a
          ###      natural fit.  Just a plain error message and line number
          ###      should do.
        puts
        puts "Full backtrace:"
        puts e.backtrace.join("\n").___indent(2)
        puts
        puts "Because we have essentially encountered a syntax error, we are exiting."
        exit!

      rescue ErrorOccurred
        # This happens when 'action' caught an exception and raised
        # ErrorOccurred.  It has already dealt with it by reporting it etc., so
        # we can just ignore it.  If we don't rescue it here, it will be rescued
        # in the clause below.
        # TODO: see if we can do the processing here instead...
        # We re-raise it so it's consistent with the clause below.
        raise

      rescue Exception => e
        ## An error has occurred while running a test.  We report the error and
        ## then raise Attest::ErrorOccurred so that the code running the test
        ## knows an error occurred.  It doesn't need to do anything with the
        ## error; it's just a signal.
        @output.report_uncaught_exception block, e, @current_test, @stats, @calls
          # ^^^ I seriously wonder whether this line is necessary.  Exceptions
          # are caught in Assertion::True#run etc.
          # Oh I see... they're only caught there if the code containing the
          # execution is executed directly:
          #    T "foo".frobnosticate?
          #  However, it's equally possible to be executed indirectly:
          #    T { "foo".frobnosticate? }
          #  In which case, they're handled in 'action'.
          #  Maybe all exceptions can be handled here...
          #  I need to check: does the fail-fast behaviour work if the error
          #  occurs in a block?  (i.e. does it raise ErrorOccurred?)
        raise ErrorOccurred

      ensure
        @calls.pop
      end
    end  # call


  end  # class << Attest

  @stats  = Hash.new {|h,k| h[k] = 0 }

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
  @nested_level = 0      # Should be equal to @tests.size.
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
