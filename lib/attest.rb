require 'dev-utils/debug'   # During development only.
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

  class << Attest
    ##
    # Hash of test results, assembled by {Attest.run}.
    #
    # [:trace]
    #   Hierarchical trace of all tests executed, where each test is
    #   represented by its description, is mapped to an Array of
    #   nested tests, and may contain zero or more assertion failures.
    #
    #   Assertion failures are represented as a Hash:
    #
    #   [:fail]
    #     Description of the assertion failure.
    #
    #   [:code]
    #     Source code surrounding the point of failure.
    #
    #   [:vars]
    #     Local variables visible at the point of failure.
    #
    #   [:call]
    #     Stack trace leading to the point of failure.
    #
    # [:stats]
    #   Hash of counts of major events in test execution:
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
    attr_reader :report

    ##
    # Hash of choices that affect how Attest operates.
    #
    # [:debug]
    #   Launch an interactive debugger
    #   during assertion failures so
    #   the user can investigate them.
    #
    #   The default value is $DEBUG.
    #
    # [:quiet]
    #   Do not print the report
    #   after executing all tests.
    #
    #   The default value is false.
    #
    attr_accessor :options

    def current_test
      $__attest_test
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

    # Registers the given block to be executed
    # before each nested test inside this test.
    def <(*args, &block)
      if args.empty?
        raise ArgumentError, 'block must be given' unless block
        @current_suite.before_each << block
      else
        # the < method is being used as a check for inheritance
        super
      end
    end

    # Registers the given block to be executed
    # after each nested test inside this test.
    def > &block
      raise ArgumentError, 'block must be given' unless block
      @current_suite.after_each << block
    end

    # Registers the given block to be executed
    # before all nested tests inside this test.
    def << &block
      raise ArgumentError, 'block must be given' unless block
      @current_suite.before_all << block
    end

    # Registers the given block to be executed
    # after all nested tests inside this test.
    def >> &block
      raise ArgumentError, 'block must be given' unless block
      @current_suite.after_all << block
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
          report_failure assertion.block, assertion.message
        end
      rescue => e
        # TODO: make this the (only) place where we do
        #   @stats[:error] += 1
        # (if possible)
        report_uncaught_exception test.block, e
      end
      passed
    end

    # Adds the given messages to the report inside
    # the section of the currently running test.
    #
    #   L "establishing connection..."
    #   L "beginning calculation...", value1, value2
    #
    def L *messages
      @trace.concat messages
      # TODO: remove this method, and remove every occurence of the @trace
      # variable.  It's not being used anywhere.
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
    # Executes all tests defined thus far and stores the results in
    # {Attest.report}.
    #
    def run
      # clear previous results
      @stats.clear
      @trace.clear
      @tests.clear

      # make new results
      start = Time.now
      catch(:stop_dfect_execution) do
        execute       # <-- This is where the real action takes place.
      end
      finish = Time.now
      @stats[:time] = finish - start

      display_results_npass_nfail_nerror_etc

      @current_suite = Suite.new
      # ^^^ In case 'run' gets called again; we don't want to re-run the old tests.
    end

    # Stops the execution of the {Attest.run} method or raises
    # an exception if that method is not currently executing.
    def stop
      throw :stop_dfect_execution
    end

    # Returns the details of the failure that
    # is currently being debugged by the user.
    def info
      @trace.last
      # TODO: remove this method; it's not being used.
    end

    private

    # For debugging: prints a summary of @current_suite, @tests and @calls to stdout.
    def dump
      puts "SUITE".bold
      puts @current_suite.to_yaml.yellow.bold
      puts "TRACE".bold
      puts @trace.to_yaml.green.bold
    end

    def nested_space
      "  " * @nested_level
    end

    # Executes the current test suite recursively.  A SUITE is a collection of D
    # blocks, and the contents of each D block is a TEST, comprising a
    # description and a block of code.  Because a test block may contain D
    # statements within it, when a test block is run @current_suite is set to
    # Suite.new so that newly-encountered tests can be added to it.  That suite
    # is then executed recursively.  The invariant is this: @current_suite is
    # the CURRENT suite to which tests may be added.  At the end of 'execute',
    # @current_suite is restored to its previous value.
    def execute
      stored_suite = current_suite = @current_suite
      trace = @trace
      @nested_level += 1
      current_suite.before_all.each {|b| call b }
      current_suite.tests.each do |test|
        current_suite.before_each.each {|b| call b }
        @tests.push test
        $__attest_test = @tests.last.desc
        begin
          debug "#{nested_space}execute: start -- #{current_test}".green.bold
          # Create nested suite in case a 'D' is encountered while running the
          # test -- this would cause 'create_test' to be called, which would run
          # code like @current_suite.tests << Test.new(...).
          @current_suite = Suite.new
          @trace = []

          # Run the test block, which may create new tests along the way (if the
          # block includes any calls to 'D').
          call test.block, test.sandbox

          # Execute the nested suite.  Nothing will happen if there are no tests
          # in the nested suite because before_all, tests and after_all will be
          # empty.
          execute
        rescue ErrorOccurred => e
          # By rescuing ErrorOccurred here, we prevent the nested 'execute'
          # above from running.  The error goes no further; the next action is
          # to go back to the outer suite and continue executing from there.
          puts "An error occurred while running test #{current_test}."
          puts "We are not continuing with that suite."
          # TODO: I don't think we really want to print the above message.  We
          # may want to record the error having occurred though...and maybe the
          # stack trace for potential debugging.
        ensure
          # Restore the previous values of @current_suite, @trace and @tests.
          @current_suite = stored_suite
          trace << build_exec_trace(@trace)
          @trace = trace
        end
        @tests.pop
        $__attest_test = (@tests.empty?) ? "(toplevel)" : @tests.last.desc
        current_suite.after_each.each {|b| call b }
      end   # loop through tests in current suite
      current_suite.after_all.each {|b| call b }
      @nested_level -= 1
      debug "#{nested_space}execute: end -- #{current_test}".red.bold
    end

    # === Attest.call
    #
    # Invokes the given block and debugs any exceptions that may arise as a result.
    # The block can be from a Test object or a "before-each"-style block.
    #
    def call block, sandbox = nil
      begin
        @calls.push block

        debug "#{nested_space}call: --> #{current_test}"

        catch :terminate_suite do
          if sandbox
            sandbox.instance_eval(&block)
          else
            block.call
          end
        end

        debug "#{nested_space}call: <-- #{current_test}"

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
        debug "#{nested_space}call: (ERROR) #{current_test}"
        raise ErrorOccurred

      ensure
        @calls.pop
      end
    end

    def create_test insulate, *description, &block
      raise ArgumentError, 'block must be given' unless block
      description = description.join(' ')
      sandbox = Object.new if insulate
      debug "#{nested_space}create_test #{description}".yellow.bold
      @current_suite.tests << Suite::Test.new(description, block, sandbox)
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

      name_of_test = @tests.map { |t| t.desc }.join(' ')
      puts
      puts "FAIL".red.bold + ": " + name_of_test.white.bold
      puts code(file, line).___indent(4) if file
      if message
        if Array === message
          puts message.inspect
        end
        puts message.___indent(2)
      else
        puts "No message! #{__FILE__}:#{__LINE__}"
      end
      puts "  Backtrace\n" + backtrace.join("\n").___indent(4)
      if vars = variables(context)
        puts "  Variables\n" + vars.___indent(4)
      end
    end  # report_failure

    def report_uncaught_exception context, exception
      @stats[:error] += 1
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

      name_of_test = @tests.map { |t| t.desc }.join(' ')
      puts
      puts "ERROR".magenta.bold + ": " + name_of_test.white.bold
      puts code(file, line).___indent(4) if file and file != "(eval)"
      puts "  Class:   ".magenta.bold + exception.class.to_s.yellow.bold
      puts "  Message: ".magenta.bold + exception.message.yellow.bold
      puts "  Backtrace\n" + backtrace.join("\n").___indent(4)
      if vars = variables(context)
        puts "  Variables\n" + vars.___indent(4)
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

    # Returns a report that associates the given
    # failure details with the currently running test.
    def build_exec_trace details
      if @tests.empty?
        details
      else
        { @tests.last.desc => details }
      end
    end

    class Suite # @private
      attr_reader :tests, :before_each, :after_each, :before_all, :after_all

      def initialize
        @tests       = []
        @before_each = []
        @after_each  = []
        @before_all  = []
        @after_all   = []
      end

      Test = Struct.new(:desc, :block, :sandbox) # @private
    end

  end  # class << Attest

  @options = {:debug => $DEBUG, :quiet => false}

  @stats  = Hash.new {|h,k| h[k] = 0 }
  @trace  = []
  @report = {:trace => @trace, :stats => @stats}.freeze

  @current_suite = class << self; Suite.new; end
  @nested_level = 0
  @share = {}
  @tests = []
  @calls = []
  @files = Hash.new {|h,k| h[k] = File.readlines(k) rescue nil }

  # Allows before and after hooks to be specified via the
  # following method syntax when this module is mixed-in:
  #
  #   D .<< { puts "before all nested tests" }
  #   D .<  { puts "before each nested test" }
  #   D .>  { puts "after  each nested test" }
  #   D .>> { puts "after  all nested tests" }
  #
  D = self

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
