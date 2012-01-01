module Whitestone

  # ==============================================================section==== #
  #                                                                           #
  #                             Custom assertions                             #
  #                                                                           #
  #         Assertion::Custom < Assertion::Base     (below)                   #
  #          - responsible for creating and running custom assertions         #
  #                                                                           #
  #         Assertion::Custom::CustomTestContext    (next section)            #
  #          - provides a context in which custom assertions can run          #
  #                                                                           #
  # ========================================================================= #

  #
  # Whitestone::Assertion::Custom  -- custom assertions
  #
  # This class is responsible for _creating_ and _running_ custom assertions.
  #
  # Creating:
  #   Whitestone.custom :circle, {
  #     :description => "Circle equality",
  #     :parameters  => [ [:circle, Circle], [:values, Array] ],
  #     :run => lambda {
  #       x, y, r, label = values
  #       test('x')     { Ft circle.centre.x,  x            }
  #       test('y')     { Ft circle.centre.y,  y            }
  #       test('r')     { Ft circle.radius,    r            }
  #       test('label') { Eq circle.label,     Label[label] }
  #     }
  #   }
  # * (Whitestone.custom passes its arguments straight through to Custom.define,
  #   which is surprisingly a very lightweight method.)
  #
  # Running:
  #   T :circle, circle, [4,1, 10, nil]
  #     --> assertion = Custom.new(:custom, :assert, :circle, circle, [4,1, 10, nil]
  #     --> assertion.run
  #
  # Custom _is_ an assertion (Assertion::Base) object, just like True,
  # Equality, Catch, etc.  It follows the same methods and life-cycle:
  # * initialize: check arguments are sound; store instance variables for later
  # * run: use the instance variables to perform the necessary assertion
  # * message: return a message to be displayed upon failure
  #
  # _run_ is a lot more complicated than a normal assertion because all the
  # logic is in the Config object (compare Equality#run: {@object == @expected}).
  # The block that is specified (the _lambda_ above) needs to be run in a
  # special context for those {test} calls to work.
  #
  class Assertion::Custom < Assertion::Base

    # Whitestone::Assertion::Custom::Config
    #
    # The Config object is what makes each custom assertion different.
    # For example (same as the example given in Custom):
    #   name = :circle
    #   description = "Circle equality"
    #   parameters = [ [:circle, Circle], [:values, Array] ]
    #   run_block = lambda { ... }
    #
    class Config
      attr_reader :name, :description, :parameters, :run_block
      def initialize(name, hash)
        @name        = name
        @description = hash[:description]
        @parameters  = hash[:parameters]
        @run_block   = hash[:run]
      end
    end

    @@config = Hash.new   # { :circle => Config.new(...), :square => Config.new(...) }

    # Custom.define
    #
    # Defines a new custom assertion -- just stores the configuration away for
    # retrieval when the assertion is run.
    def self.define(name, definition)
      @@config[name] = Config.new(name, definition)
    end

    # Custom#initialize
    #
    # Retrieves the config for the named custom assertion and checks the
    # arguments against the configured parameters.
    #
    # Sets up a context (CustomTestContext) for running the assertion when #run
    # is called.
    def initialize(mode, *args, &block)
      name = args.shift
      super(mode, *args, &block)
      no_block_allowed
      @config = @@config[name]
      if @config.nil?
        message = "Non-existent custom assertion: #{name.inspect}"
        raise AssertionSpecificationError, message
      end
      check_args_against_parameters(args)
      @context = CustomTestContext.new(@config.parameters, args)
    end

    # Custom#run
    #
    # Returns true or false for pass or fail, just like other assertions.
    #
    # The Config object provides the block to run, while @context provides the
    # context in which to run it.
    #
    # We trap FailureOccurred errors because as a _custom_ assertion we need to
    # take responsibility for the errors, and wrap some information around the
    # error message.
    def run
      test_code = @config.run_block
      @context.instance_eval &test_code
        # ^^^ This gives the test code access to the 'test' method that is so
        #     important for running a custom assertion.
        #     See the notes on CustomTestContext for an example.
      return true  # the custom test passed
    rescue FailureOccurred => f
      # We are here because an assertion failed.  That means _this_ (custom)
      # assertion has failed.  We need to build an error message and raise
      # FailureOccurred ourselves.
      @message = String.new.tap { |str|
	str << Col["#{@config.description} test failed: "].yb
	str << Col[@context.context_label].cb
	str << Col[" (details below)\n", f.message.___indent(4)].fmt(:yb, :yb)
      }
      return false
    rescue AssertionSpecificationError => e
      # While running the test block, we got an AssertionSpecificationError.
      # This probably means some bad data was put in, like
      #    T :circle, c, [4,1, "radius", nil]
      # (The radius needs to be a number, not a string.)
      # We will still raise the AssertionSpecificationError but we want it to
      # look like it comes from the _custom_ assertion, not the _primitive_
      # one.  Essentially, we are acting like it's a failure: constructing the
      # message that includes the context label (in this case, 'r' for
      # radius).
      message = String.new.tap { |str|
	str << Col["#{@config.description} test -- error: "].yb
	str << Col[@context.context_label].cb
	str << Col[" details below\n", e.message.___indent(4)].fmt(:yb, :yb)
      }
      raise AssertionSpecificationError, message
    end

    # Custom#message
    #
    # If a failure occurred, a failure message was prepared when the exception
    # was caught in #run.
    def message
      @message
    end

    # e.g. parameters = [ [:circle, Circle], [:values, Array] ]
    #            args = [ some_circle, [3,1,10,:X] ]
    # That's a match.
    # For this method, we're not interested in the names of the parameters.
    def check_args_against_parameters(args)
      parameters = @config.parameters
      parameter_types = parameters.map { |name, type| type }
      if args.size != parameter_types.size
        msg = "Expect #{parameter_types.size} arguments after " \
              "#{@config.name.inspect}; got #{args.size}"
        raise AssertionSpecificationError, msg
      end
      args.zip(parameter_types).each do |arg, type|
        unless arg.is_a? type
          msg = "Argument error: expected #{type}; "\
                "got #{arg.inspect} (#{arg.class})"
          raise AssertionSpecificationError, msg
        end
      end
    end
    private :check_args_against_parameters

  end  # class Assertion::Custom


    # ------------------------------------------------------------section---- #
    #                                                                         #
    #                            CustomTestContext                            #
    #                                                                         #
    # ----------------------------------------------------------------------- #


  ##
  # CustomTestContext -- an environment in which a custom text can run
  # and have access to its parameters.
  #
  # Example usage (test writer's point of view):
  #
  #   Whitestone.custom :circle, {
  #     :description => "Circle equality",
  #     :parameters  => [ [:circle, Circle], [:values, Array] ],
  #     :run => lambda {
  #       x, y, r, label = values
  #       test('x')     { Ft x, circle.centre.x         }
  #       test('y')     { Ft y, circle.centre.y         }
  #       test('r')     { Ft r, circle.radius           }
  #       test('label') { Eq Label[label], circle.label }
  #     }
  #   }
  #
  # That _lambda_ on Line 4 gets evaluated in a CustomTestContext object, which
  # gives it access to the method 'test' and the parameters 'circle' and
  # 'values', which are dynamically-defined methods on the context object.
  #
  # Example usage (CustomTestContext user's point of view):
  #
  #   context = CustomTestContext.new(parameters, arguments)
  #   context.instance_eval(block)
  #
  class Assertion::Custom::CustomTestContext
    # The label associated with the current assertion (see #test).
    attr_reader :context_label

    # Example:
    #   parameters: [ [:circle, Circle], [:values, Array] ],
    #       values: [ circle_object, [4,1,5,:X] ]
    # Result of calling method:
    #   def circle() circle_object end
    #   def values() [4,1,5,:X]    end
    # Effect:
    # * code run in this context (i.e. with this object as 'self') can access
    #   the methods 'circle' and 'values', as well as the method 'test'.
    def initialize(parameters, values)
      parameters = parameters.map { |name, type| name }
      parameters.zip(values).each do |param, value|
        metaclass = class << self; self; end
        metaclass.module_eval do
          define_method(param) { value }
        end
      end
    end

    # See the example usage above.  The block is expected to have a single
    # assertion in it (but of course we can't control or even check that).
    #
    # If the assertion fails, we use the label as part of the error message
    # so it's easy to see what went wrong.
    #
    # Therefore we save the label so the test runner that is using this
    # context can access it.  In the example above, the value of 'context_label'
    # at different times throughout the lambda is 'x', 'y', 'r' and 'label'.
    def test(label, &assertion)
      @context_label = label
      assertion.call
    end
  end  # class Assertion::Custom::CustomTestContext

end  # module Whitestone
