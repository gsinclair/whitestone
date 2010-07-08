
require 'set'
require 'differ'
module BoldColor
  class << self
    def format(change)
      (change.change? && as_change(change)) ||
        (change.delete? && as_delete(change)) ||
        (change.insert? && as_insert(change)) ||
        ''
    end
    private
    def as_insert(change) change.insert.green.bold               end
    def as_delete(change) change.delete.red.bold                 end
    def as_change(change) as_delete(change) << as_insert(change) end
  end
end
Differ.format = BoldColor

# --------------------------------------------------------------------------- #

module Attest

  module Assertion

    ##
    # Various methods to guard against invalid assertions.  All of these raise
    # AssertionSpecificationError if there is a problem.
    #
    module Guards
      extend self   # All methods here may be mixed in or called directly;
                    # e.g. Assertion::Guards.type_check("foo", String)

      ## Return a lambda that can be run.  If the user specified a block, it's
      ## that.  If not, it's the first argument.  If both or neither, it's an
      ## error.  If there's more arguments than necessary, it's an error.
      def args_or_block_one_only(args, block)
        if block and args.empty?
          block
        elsif !block and args.size == 1
          lambda { args.first }
        else
          raise AssertionSpecificationError, "Improper arguments to T"
        end
      end

      def one_argument(array)
        unless array.size == 1
          raise AssertionSpecificationError, "Exactly one argument required"
        end
        array.first
      end

      def two_arguments(array)
        unless array.size == 2
          raise AssertionSpecificationError, "Exactly two arguments required"
        end
        array
      end

      def two_or_three_arguments(array)
        unless array.size == 2 or array.size == 3
          raise AssertionSpecificationError, "Exactly two or three arguments required"
        end
        array
      end

      def no_block_allowed
        if @block
          raise AssertionSpecificationError, "This method doesn't take a block"
        end
      end

      def block_required(block)
        unless block
          raise AssertionSpecificationError, "The method requires a block"
        end
        block
      end

      def type_check(args, types)
        if Class === types
          types = args.map { types }
        end
        if types.size != args.size
          raise AssertionSpecificationError, "Incorrect number of types provided"
        end
        args.zip(types).each do |arg, type|
          unless arg.is_a? type
            msg = "Argument error: expected #{type}; "\
                  "got #{arg.inspect} (#{arg.class})"
            raise AssertionSpecificationError, msg
          end
        end
      end

      ### def type_check(args, types)
      ###   correct =
      ###     case types
      ###     when Array     # Arguments must match types in order.
      ###       args.zip(types).all? { |arg, type| arg.is_a? type }
      ###     when Class
      ###       # All of the arguments must be of the given type
      ###       args.all? { |arg| arg.kind_of? types }
      ###     end
      ###   unless correct
      ###     raise AssertionSpecificationError,
      ###       "Type failure: expect #{types.inspect}; got ..."
      ###   end
      ### end
    end  # module Assertion::Guards

    # ----------------------------------------------------------------------- #

    ##
    # A class in the Assertion namespace meets the following criteria:
    #   def initialize(mode, *args, &block)
    #   def run  # -> true or false (representing pass or fail)
    #
    # The idea is to support T, F, Eq, etc.  The initialize method ensures the
    # correct number, type and combination of arguments are provided (e.g. you
    # can't provide and argument _and_ a block for T, F or N).
    #
    # Any Assertion::XYZ object answers to #block (to provide the context of a
    # failure or error; may be nil) and #message (which returns the message the
    # user sees).
    #
    # Every subclass must call *super* in its initialize method so that the mode
    # and the block can be correctly stored.
    #
    class Base
      include Assertion::Guards
      def initialize(mode, *args, &block)
        @mode   = mode
        @block  = block
      end

      def block
        @block
      end

      def message
        "No message implemented for class #{self.class} yet."
      end
    end  # class Assertion::Base

    # ----------------------------------------------------------------------- #

    class True < Base
      def initialize(mode, *args, &block)
        super
        @test_lambda = args_or_block_one_only(args, block)
      end
      def run
        @test_lambda.call ? true : false
      end
      def message
        "Assertion failed".yellow.bold
      end
    end  # class Assertion::True

    class False < True
      def run
        not super     # False is the _opposite_ of True
      end
    end  # class Assertion::False

    class Nil < Base
      def initialize(mode, *args, &block)
        super
        @test_lambda = args_or_block_one_only(args, block)
      end
      def run
        @test_lambda.call.nil?
      end
      def message
        msg = 'Condition expected NOT to be nil'.yellow.bold
        case @mode
        when :assert then msg.sub(' NOT', '')
        when :negate then msg
        end
      end
    end  # class Assertion::Nil

    class Equality < Base
      def initialize(mode, *args, &block)
        super
        @actual, @expected = two_arguments(args)
        no_block_allowed
      end
      def run
        @expected == @actual
      end
      def message
        case @mode
        when :assert
          String.new.tap { |str|
            str << "Equality test failed\n".yellow.bold
            str << "  Should be: #{@expected.inspect}\n".green.bold
            str << "        Was: #{@actual.inspect}".red.bold
            if String === @actual and String === @expected \
                 and @expected.length > 40 and @actual.length > 40
              diff = Differ.diff_by_char(@expected.inspect, @actual.inspect)
              str << "\n" << "  Dif: #{diff}"
            end
          }
        when :negate
          if @expected.inspect.length < 10
            ("Inequality test failed: object should not " +
            "equal #{@expected.inspect.red.bold}").yellow.bold
          else
            ("Inequality test failed: the two objects were equal.\n" <<
            "  Value: #{@expected.inspect.red.bold}"). yellow.bold
          end
        end
      end
    end  # class Assertion::Equality

    class Match < Base
      def initialize(mode, *args, &block)
        super
        no_block_allowed
        args = two_arguments(args)
        unless args.map { |a| a.class }.to_set == Set[Regexp, String]
          raise AssertionSpecificationError, "Expect a String and a Regexp (any order)"
        end
        @regexp, @string = args
        if String === @regexp
          @string, @regexp = @regexp, @string
        end
      end
      def run
        @regexp =~ @string
      end
      def message
        _not_ =
          case @mode
          when :assert then " "
          when :negate then " NOT "
          end
        "Match failure: string should#{_not_}match regex\n".yellow.bold <<
        "  String: #{@string.inspect.___truncate(200).red.bold}\n" <<
        "  Regexp: #{@regexp.inspect.green.bold}"
      end
    end  # class Assertion::Match

    class KindOf < Base
      def initialize(mode, *args, &block)
        super
        no_block_allowed
        args = two_arguments(args)
        type_check(args, [Object,Module])
        @object, @klass = args
      end
      def run
        @object.kind_of? @klass
      end
      def message
        _not_ =
          case @mode
          when :assert then " "
          when :negate then " NOT "
          end
        "Type failure: object expected#{_not_}to be of type #{@klass}\n".yellow.bold <<
        "  Object's class is ".yellow.bold + @object.class.to_s.red.bold
      end
    end  # class Assertion::KindOf

    class FloatEqual < Base
      EPSILON = 0.000001
      def initialize(mode, *args, &block)
        super
        no_block_allowed
        type_check(args, Numeric)
        @actual, @expected, @epsilon = two_or_three_arguments(args).map { |x| x.to_f }
        @epsilon ||= EPSILON
      end
      def run
        difference = (@expected - @actual).abs
        # we want the difference to be a small percentage of the expected value
        difference.zero? or (difference / @expected) <= @epsilon
      end
      def message
        String.new.tap { |str|
          case @mode
          when :assert
            str << "Float equality test failed\n".yellow.bold
            str << "  Should be: #{@expected.inspect}\n".green.bold
            str << "        Was: #{@actual.inspect}\n".red.bold
            str << "    Epsilon: #{@epsilon.inspect}"
          when :negate
            str << "Float inequality test failed: " \
                        "the two values were essentially equal.\n".yellow.bold
            str << "      Value: #{@expected.inspect.red.bold}\n".yellow.bold
            str << "    Epsilon: #{@epsilon}"
          end
        }
      end
    end

    class ExpectError < Base
      def initialize(mode, *args, &block)
        super
        @exceptions = args.empty? ? [StandardError] : args
        unless @exceptions.all? { |klass| klass.is_a? Class }
          raise AssertionSpecificationError, "Invalid arguments: must all be classes"
        end
        @block = block_required(block)
      end
      def run
        # Return true if the block raises an exception, false otherwise.
        # Only the exceptions specified in @exceptions will be caught.
        begin
          @block.call
          return false
        rescue ::Exception => e
          if @exceptions.any? { |klass| e.is_a? klass }
            @exception_class = e.class
            Attest.exception = e
            return true
          else
            raise e  # It's not one of the exceptions we wanted; re-raise it.
          end
        end
      end
      def message
        msg = (
          kinds_str = @exceptions.map { |ex| ex.to_s.red.bold }.
                                  join(' or '.yellow.bold)
          case @mode
          when :assert 
            ["Expected block to raise #{kinds_str}", "; nothing raised"]
          when :negate
            str = @exception_class.to_s.red.bold
            ["Expected block NOT to raise #{kinds_str}", "; #{str}", " raised"]
          end
        )
        msg.map { |str| str.yellow.bold }.join
      end
    end  # class Assertion::Exception

    class Catch < Base
      TOKEN = Object.new
      def initialize(mode, *args, &block)
        super
        @symbol = one_argument(args)
        @block = block_required(block)
      end
      def run
        return_value =
          catch(@symbol) do
            begin
              @block.call
            rescue => e
              raise e unless e.message =~ /\Auncaught throw (`.*?'|:.*)\z/
              # ^ We don't want this exception to escape and terminate our
              #   tests.  TODO: make sure I understand this and agree with
              #   what it does.  Should we report an uncaught throw?
            end
            TOKEN  # Special object to say we reached the end of the block,
                   # therefore nothing was thrown.
          end
        if return_value == TOKEN
          # The symbol we were expecting was not thrown, so this test failed.
          Attest.caught_value = nil
          return false
        else
          Attest.caught_value = return_value
          return true
        end
      end
      def message
        symbol = @symbol.to_sym.inspect.red.bold
        msg =
          case @mode
          when :assert
            ["Expected block to throw #{symbol}", "; it didn't"]
          when :negate
            ["Expected block NOT to throw #{symbol}", "; it did"]
          end
        msg.map { |str| str.yellow.bold }.join
      end
    end  # class Assertion::Catch

    # ----------------------------------------------------------------------- #

    class Custom < Base

      ### class CustomAssertionUndefined < StandardError; end

      class Config
        attr_reader :name, :description, :parameters, :run_block
        def initialize(name, hash)
          @name        = name
          @description = hash[:description]
          @parameters  = hash[:parameters]
          @run_block   = hash[:run]
        end
      end

      @@config = Hash.new

      def Custom.define(name, definition)
        @@config[name] = Config.new(name, definition)
      end

      def Custom.config(name)
        @@config[name]
      end

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

      def run
        ### Attest.inside_custom_assertion do
          test_code = @config.run_block
          @context.instance_eval &test_code
            # ^^^ This gives the block access to the 'test' method that is so
            #     important for running a custom assertion.
        ### end
        return true  # the custom test passed
      rescue FailureOccurred => f
        debug "FailureOccurred: #{f.inspect}".red.bold
        # We are here because an assertion failed.  That means _this_ (custom)
        # assertion has failed.  We need to build an error message and raise
        # FailureOccurred ourselves.
        @message = "#{@config.description} test failed: ".yellow.bold
        @message << @context.label.cyan.bold
        @message << " (details below)\n".yellow.bold
        @message << f.message.___indent(2)
        ### backtrace = caller    # XXX: I _think_ this is what we want.
        ### raise FailureOccurred.new(f.context, message, f.backtrace)
        return false  # the custom test failed
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
        debug "Custom#run: AssertionSpecificationError"
        message = "#{@config.description} test -- error: ".yellow.bold
        message << @context.label.cyan.bold
        message << " (details below)\n".yellow.bold
        message << e.message.___indent(4).yellow.bold
        raise AssertionSpecificationError, message
      end

      def message
        @message  # prepared earlier
      end

      # e.g. parameters = [ [:circle, Circle], [:values, Array] ]
      #            args = [ some_circle, [3,1,10,:X] ]
      # That's a match.
      # For this method, we're not interested in the names of the parameters.
      # (In fact, I'm not sure we ever are...)
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

      ##
      # CustomTestContext -- an environment in which a custom text can run
      # and have access to its parameters.
      #
      # Example usage:
      #
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
      #
      # That _lambda_ gets evaluated in a CustomTestContext object, which gives
      # it access to the method 'test' and the virtual methods 'circle' and
      # 'values' (implemented via method_missing).
      class CustomTestContext
        # The label associated with the current assertion (see #test).
        attr_reader :label

        def initialize(parameters, values)
          @parameter = Hash.new
          parameters = parameters.map { |name, type| name }
          parameters.zip(values).each do |param, value|
            @parameter[param] = value
          end
        end

        # See the example usage above.  The block is expected to have a single
        # assertion in it (but of course we can't control or even check that).
        #
        # If the assertion fails, we use the label as part of the error message
        # so it's easy to see what went wrong.
        #
        # Therefore we save the label so the test runner that is using this
        # context can access it.  In the example above, the value of 'label' at
        # different times throughout the lambda is 'x', 'y', 'r' and 'label'.
        def test(label, &assertion)
          @label = label
          debug "CustomTestContext#test(#{label.inspect}, #{assertion.inspect})".green.bold
          assertion.call
        end

        def method_missing(name, *args, &block)
          if @parameter.key? name
            debug "  -> CustomTestContext: accessed parameter #{name.inspect}"
            @parameter[name]
          else
            raise NoMethodError, "CustomTestContext: #{name}"
          end
        end
      end  # class CustomTestContext

    end  # class Assertion::Custom

  end  # module Assertion

end  # module Attest
