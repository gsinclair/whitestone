
module Attest

  ## A class in the Assertion namespace meets the following criteria:
  ##   def initialize(*args, &block)
  ##   def run  # -> true or false (representing pass or fail)
  ##
  ## The idea is to support T, F, Eq, etc.  The initialize method ensures the
  ## correct number, type and combination of arguments are provided (e.g. you
  ## can't provide and argument _and_ a block for T, F or N).

  module Assertion
    class Base
      def initialize(*args, &block)
        @block = block
      end

      def message(mode=:assert)
        "No message implemented for class #{self.class} yet."
      end

      ## Return a lambda that can be run.  If the user specified a block, it's
      ## that.  If not, it's the first argument.  If both or neither, it's an
      ## error.  If there's more arguments than necessary, it's an error.
      def args_or_block_one_only(*args, &block)
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

      def no_block_allowed(&block)
        if block
          raise AssertionSpecificationError, "This method doesn't take a block"
        end
      end

      def block_required(block)
        unless block
          raise AssertionSpecificationError, "The method requires a block"
        end
        block
      end
    end  # class Assertion::Base

    class True < Base
      def initialize(*args, &block)
        super
        @test_lambda = args_or_block_one_only(*args, &block)
      end
      def run
       @test_lambda.call
      end
    end  # class Assertion::True

    class False < True
      def run
        not super     # False is the _opposite_ of True
      end
    end  # class Assertion::False

    class Nil < Base
      def initialize(*args, &block)
        super
        @test_lambda = args_or_block_one_only(*args, &block)
      end
      def run
       @test_lambda.call.nil?
      end
    end  # class Assertion::Nil

    class Equality < Base
      def initialize(*args, &block)
        super
        @actual, @expected = two_arguments(args)
        no_block_allowed(block)
      end
      def run
        @expected == @actual
      end
    end  # class Assertion::Equality

    class Match < Base
      def initialize(*args, &block)
        super
        @regex, @string = two_arguments(args)
        no_block_allowed(block)
      end
      def run
        @regex =~ @string
      end
    end  # class Assertion::Match

    class Exception < Base
      def initialize(*args, &block)
        super
        @exceptions = args
        unless @exceptions.all? { |klass| klass.is_a? Class }
          raise AssertionSpecificationError, "Invalid arguments: must all be classes"
        end
        @block = block_required(block)
      end
      def run
        # Return true if the block raises an exception, false otherwise.
        # Only the exceptions specified in @exceptions will be caught.
        result = false
        begin
          @block.call
          result = false
        rescue => e
          if @exceptions.any? { |klass| e.is_a? klass }
            result = true
          else
            raise e  # It's not one of the exceptions we wanted; re-raise it.
          end
        end
        result   # Return the result: true or false.
      end
    end  # class Assertion::Exception

    class Catch < Base
      TOKEN = Object.new
      def initialize(*args, &block)
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
          return false
        else
          return true
        end
      end
    end  # class Assertion::Catch

  end  # module Assertion

end  # module Attest
