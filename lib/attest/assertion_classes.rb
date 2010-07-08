
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

  end  # module Assertion
end  # module Attest

