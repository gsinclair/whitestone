
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
    def as_insert(change) Col[change.insert].green.bold.to_s     end
    def as_delete(change) Col[change.delete].red.bold.to_s       end
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
        Col["Assertion failed"].yb
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
        msg = Col['Condition expected NOT to be nil'].yb
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
            str << Col["Equality test failed"].yb
            str << Col["\n  Should be: ", @expected.inspect].fmt(:yb, :gb)
            str << Col["\n        Was: ", @actual.inspect].fmt(:rb, :rb)
            if String === @actual and String === @expected \
                 and @expected.length > 40 and @actual.length > 40
              diff = Differ.diff_by_char(@expected.inspect, @actual.inspect)
              str << "\n" << "  Dif: #{diff}"
            end
          }
        when :negate
          if @expected.inspect.length < 10
            Col["Inequality test failed: object should not equal",
                    @expected.inspect].fmt [:yb, :rb]
          else
            Col.inline(
              "Inequality test failed: the two objects were equal.\n",  :yb,
              "  Value: ",                                              :yb,
              @expected.inspect,                                        :rb
            )
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
        @string = Col.uncolored(@string)
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
        String.new.tap { |str|
          string = Col.plain(@string).inspect.___truncate(200)
          regexp = @regexp.inspect
          str << Col["Match failure: string should#{_not_}match regex\n"].yb.to_s
          str << Col["  String: ", string].fmt('yb,rb') << "\n"
          str << Col["  Regexp: ", regexp].fmt('yb,gb')
        }
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
        Col.inline(
          "Type failure: object expected#{_not_}to be of type #{@klass}\n", :yb,
          "  Object's class is ",                                           :yb,
                               @object.class,                               :rb
        )
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
        if @actual.zero? or @expected.zero?
          # There's no scale, so we can only go on difference.
          (@actual - @expected) < @epsilon
        else
          # We go by ratio. The ratio of two equal numbers is one, so the ratio
          # of two practically-equal floats will be very nearly one.
          @ratio = (@actual/@expected - 1).abs
          @ratio < @epsilon
        end
      end
      def message
        String.new.tap { |str|
          case @mode
          when :assert
            str << Col["Float equality test failed"].yb
            str << "\n" << Col["  Should be: #{@expected.inspect}"].gb
            str << "\n" << Col["        Was: #{@actual.inspect}"].rb
            str << "\n" <<     "    Epsilon: #{@epsilon}"
            if @ratio
              str << "\n" <<   "      Ratio: #{@ratio}"
            end
          when :negate
            line = "Float inequality test failed: the two values were essentially equal."
            str << Col[line].yb
            str << "\n" << Col["    Value 1: ", @actual.inspect  ].fmt(:yb, :rb)
            str << "\n" << Col["    Value 2: ", @expected.inspect].fmt(:yb, :rb)
            str << "\n" <<     "    Epsilon: #{@epsilon}"
            if @ratio
              str << "\n" <<   "      Ratio: #{@ratio}"
            end
          end
        }
      end
    end  # class Assertion::FloatEqual

    class Identity < Base
      def initialize(mode, *args, &block)
        super
        @obj1, @obj2 = two_arguments(args)
        no_block_allowed
      end
      def run
        @obj1.object_id == @obj2.object_id
      end
      def message
        String.new.tap { |str|
          case @mode
          when :assert
            str << Col["Identity test failed -- the two objects are NOT the same"].yb
            str << Col["\n  Object 1 id: ", @obj1.object_id].fmt('yb,rb')
            str << Col["\n  Object 2 id: ", @obj2.object_id].fmt('yb,rb')
          when :negate
            str << Col["Identity test failed -- the two objects ARE the same"].yb
            str << Col["\n  Object id: ", @obj1.object_id].fmt('yb,rb')
          end
        }
      end
    end  # class Assertion::Identity

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
        _or_ = Col[' or '].yb
        kinds_str = @exceptions.map { |ex| Col[ex].rb }.join(_or_)
        klass = @exception_class
        case @mode
        when :assert 
          Col["Expected block to raise ", kinds_str, "; nothing raised"].fmt 'yb,_,yb'
        when :negate
          Col[  "Expected block NOT to raise ", kinds_str, "; ", klass, " raised"].
            fmt :yb,                            :_,        :yb,  :rb,   :yb  
        end
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
        symbol = @symbol.to_sym.inspect
        case @mode
        when :assert
          Col["Expected block to throw ", symbol, "; it didn't"].fmt 'yb,rb,yb'
        when :negate
          Col["Expected block NOT to throw ", symbol, "; it did"].fmt 'yb,rb,yb'
        end
      end
    end  # class Assertion::Catch

    # ----------------------------------------------------------------------- #

  end  # module Assertion
end  # module Attest

