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
          report_failure assertion.block, assertion.message
          throw :abort_current_suite_due_to_failure
        end
      rescue => e
        # TODO: make this the (only) place where we do
        #   @stats[:error] += 1
        # (if possible)
        # UPDATE: I think it _is_ possible right now...
        report_uncaught_exception test.block, e
      end
      passed
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
      display_test_by_test_result
      display_details_of_failures_and_errors
      display_results_npass_nfail_nerror_etc

      @current_scope = Attest::Scope.new
      # ^^^ In case 'run' gets called again; we don't want to re-run the old tests.
    end

    # Record the elapsed time to execute the given block.
    def time
      start = Time.now
      yield
      finish = Time.now
      finish - start
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
    end

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
        report_uncaught_exception block, e
        puts
        puts "Full backtrace:"
        puts e.backtrace.join("\n").___indent(2)
        puts
        puts "Because we have essentially encountered a syntax error, we are exiting."
        exit!

      rescue Exception => e
        ## An error has occurred while running a test.  We report the error and
        ## then raise Attest::ErrorOccurred so that the code running the test
        ## knows an error occurred.  It doesn't need to do anything with the
        ## error; it's just a signal.
        report_uncaught_exception block, e
        raise ErrorOccurred

      ensure
        @calls.pop
      end
    end

    # Print the name and result of each test, using indentation.
    # This must be done after execution is finished in order to get the tree
    # structure right.
    def display_test_by_test_result
      puts
      puts ("------ Report " + "-" * (78-14)).cyan.bold
      tree_walk(@top_level.tests) do |test, level|
        string1 = ("  " + "  " * level + test.description).ljust(65)
        string2 = "  " + test.result.to_s.upcase
        colour = case test.result
                 when :pass then :green
                 when :fail then :red
                 when :error then :magenta
                 end
        if colour != :green
          string1 = string1.send(colour).bold
        end
        puts "" if level == 0
        puts string1 + string2.send(colour).bold
      end
      puts
      puts ("-" * 78).cyan.bold
    end

    # Yield each test and its children (along with the current level 0,1,2,...)
    # in depth-first order.
    def tree_walk(tests, level=0, &block)
      tests.each do |test|
        block.call(test, level)
        unless test.children.empty?
          tree_walk( test.children, level+1, &block )
        end
      end
    end

    def display_details_of_failures_and_errors
      puts
      puts @buf.string
    end

    # Prepares and displays a colourful summary message saying how many tests
    # have passed, failed and errored.
    def display_results_npass_nfail_nerror_etc
      npass   = @stats[:pass]  || 0
      nfail   = @stats[:fail]  || 0
      nerror  = @stats[:error] || 0
      overall = (nfail + nerror > 0) ? :FAIL : :PASS
      ntotal  = npass + nfail + nerror
      time    = @stats[:time]

      overall_colour = (if overall == :PASS then :green else :red end)
      npass_colour   = :green
      nfail_colour   = (if nfail  > 0 then :red else :green end)
      nerror_colour  = (if nerror > 0 then :magenta else :green end)
      time_colour    = :white

      overall_str   = overall.to_s.ljust(10).send(overall_colour).bold
      npass_str     = (sprintf "#pass: %-6d",  npass).send(npass_colour).bold
      nfail_str     = (sprintf "#fail: %-6d",  nfail).send(nfail_colour).bold
      nerror_str    = (sprintf "#error: %-6d", nerror).send(nerror_colour).bold
      time_str      = (sprintf "time: %s",      time).send(time_colour)

      equals = ("=" * 80).send(overall_colour).bold + "\n"
      string = equals.dup
      string << overall_str << npass_str << nfail_str << nerror_str << time_str << "\n"
      string << equals

      puts
      puts string
    end

    INTERNALS_RE = (               # @private
      libdir = File.dirname(__FILE__)
      bindir = "bin/attest"
      Regexp.union(libdir, bindir)
    )
    def filter_bactrace(b)
      b.reject { |str| str =~ INTERNALS_RE }
    end

    def report_failure context, message = nil, backtrace = caller
      context ||= @calls.last
      if context and context.respond_to? :binding
        context = context.binding
      end
      backtrace = filter_bactrace(backtrace)

      if frame = backtrace.first
        file, line = frame.scan(/(.+?):(\d+(?=:|\z))/).first
        line = line.to_i
      end

      @buf.puts
      @buf.puts "FAIL: #{current_test}".red.bold
      @buf.puts code(file, line).___indent(4) if file
      if message
        if Array === message
          @buf.puts message.inspect
        end
        @buf.puts message.___indent(2)
      else
        @buf.puts "No message! #{__FILE__}:#{__LINE__}"
      end
      @buf.puts "  Backtrace\n" + backtrace.join("\n").___indent(4)
      if vars = variables(context)
        @buf.puts "  Variables\n" + vars.___indent(4)
      end
    end  # report_failure

    def report_uncaught_exception context, exception
      @stats[:error] += 1
      @current_test.result = :error
      context ||= @calls.last
      if context and context.respond_to? :binding
        context = context.binding
      end
      backtrace = exception.backtrace
      backtrace = filter_bactrace(exception.backtrace)

      current_test_file = @calls.last.to_s.scan(/@(.+?):/).flatten.first
      frame =
        if :show_test_code_that_led_to_the_exception
          backtrace.find { |str| str.index(current_test_file) }
        elsif :show_actual_location_of_error
          backtrace.first
        end

      if frame
        file, line = frame.scan(/(.+?):(\d+(?=:|\z))/).first
        line = line.to_i
      end

      @buf.puts
      @buf.puts "ERROR: #{current_test}".magenta.bold
      @buf.puts code(file, line).___indent(4) if file and file != "(eval)"
      @buf.puts "  Class:   ".magenta.bold + exception.class.to_s.yellow.bold
      @buf.puts "  Message: ".magenta.bold + exception.message.yellow.bold
      @buf.puts "  Backtrace\n" + backtrace.join("\n").___indent(4)
      if vars = variables(context)
        @buf.puts "  Variables\n" + vars.___indent(4)
      end
    end  # report_uncaught_exception

    def code(file, line)
      if source = @files[file]
        line = line.to_i
        radius = 2 # number of surrounding lines to show
        region1 = [line - radius, 1].max .. [line - 1, 1].max
        region2 = [line]
        region3 = [line + 1, source.length].min .. [line + radius, source.length].min

        # ensure proper alignment by zero-padding line numbers
        format = "%2s %0#{region3.last.to_s.length}d %s"

        pretty1 = region1.map { |n|
          format % [nil, n, source[n-1].chomp.___truncate(60)]
        }
        pretty2 = region2.map  { |n|
          (format % ['=>', n, source[n-1].chomp.___truncate(60)]).yellow.bold
        }
        pretty3 = region3.map { |n|
          format % [nil, n, source[n-1].chomp.___truncate(60)]
        }
        pretty = pretty1 + pretty2 + pretty3

        #pretty.unshift "[#{region.inspect}] in #{file}"
        pretty.unshift file.yellow

        pretty.join("\n")
      end
    end  # code

    def variables(context)
      if context
        names = eval('::Kernel.local_variables + self.instance_variables',
                     context, __FILE__, __LINE__)
        #names = names.grep /^[a-z]/    # Ignore vars starting with underscores.
        return nil if names.empty?
        pairs = names.map { |name|
          variable = name.to_s
          value    = eval(variable, context, __FILE__, __LINE__)
          "#{variable}: #{value.inspect.___truncate(40)}"
        }.join("\n")
      end
    end

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
  @files = Hash.new {|h,k| h[k] = File.readlines(k) rescue nil }
                         # A means of printing lines of code in failure and
                         #   error details.
  @buf = StringIO.new    # Buffer into which the details of failures and errors
                         #   are written.

  # Allows before and after hooks to be specified via the
  # following method syntax when this module is mixed-in:
  #
  #   D .<< { puts "before all nested tests" }
  #   D .<  { puts "before each nested test" }
  #   D .>  { puts "after  each nested test" }
  #   D .>> { puts "after  all nested tests" }
  #
  D = ::Attest

  # provide mixin-able assertion methods
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
