
# This code was snipped from Attest and replaced by code that generates these
# methods.  Recorded here in case its needed (i.e. my grand ideas don't work).
# Will hopefully be deleted before long.

    ##
    # Asserts that the given condition or the
    # result of the given block is neither
    # nil nor false and returns that result.
    #
    # @param condition
    #
    #   The condition to be asserted.  A block
    #   may be given in place of this parameter.
    #
    # @param message
    #
    #   Optional message to show in the
    #   report if this assertion fails.
    #
    # @example no message given
    #
    #   T { true }  # passes
    #   T { false } # fails
    #   T { nil }   # fails
    #
    # @example message is given
    #
    #   T("computers do not doublethink") { 2 + 2 != 5 } # passes
    #
#   def T condition = nil, message = nil, &block
#     assert_yield :assert, condition, message, &block
#   end

#   def Eq actual, expected, message = nil
#     assert_equal :assert, actual, expected, message
#   end

#   def Eq! actual, expected, message = nil
#     assert_equal :negate, actual, expected, message
#   end

#   def Eq? actual, expected, message = nil
#     assert_equal :sample, actual, expected, message
#   end

#   def N condition = nil, message = nil, &block
#     assert_nil :assert, condition, message, &block
#   end

#   def N! condition = nil, message = nil, &block
#     assert_nil :negate, condition, message, &block
#   end

#   def N? condition = nil, message = nil, &block
#     assert_nil :sample, condition, message, &block
#   end

#   def Mt string, regex, message=nil
#     assert_match :assert, string, regex, message
#   end

#   def Mt! string, regex, message=nil
#     assert_match :negate, string, regex, message
#   end

#   def Mt? string, regex, message=nil
#     assert_match :sample, string, regex, message
#   end


    ##
    # Asserts that the given condition or the
    # result of the given block is either nil
    # or false and returns that result.
    #
    # @param condition (see Attest.T)
    #
    # @param message (see Attest.T)
    #
    # @example no message given
    #
    #   T! { true }  # fails
    #   T! { false } # passes
    #   T! { nil }   # passes
    #
    # @example message is given
    #
    #   T!("computers do not doublethink") { 2 + 2 == 5 } # passes
    #
#   def T! condition = nil, message = nil, &block
#     assert_yield :negate, condition, message, &block
#   end

    ##
    # Returns true if the given condition or
    # the result of the given block is neither
    # nil nor false.  Otherwise, returns false.
    #
    # @param condition (see Attest.T)
    #
    # @param message
    #
    #   This parameter is optional and completely ignored.
    #
    # @example no message given
    #
    #   T? { true }  # => true
    #   T? { false } # => false
    #   T? { nil }   # => false
    #
    # @example message is given
    #
    #   T?("computers do not doublethink") { 2 + 2 != 5 } # => true
    #
#   def T? condition = nil, message = nil, &block
#     assert_yield :sample, condition, message, &block
#   end

#   alias F T!

#   alias F! T

    ##
    # Returns true if the result of the given block is
    # either nil or false.  Otherwise, returns false.
    #
    # @param message (see Attest.T?)
    #
    # @example no message given
    #
    #   F? { true }  # => false
    #   F? { false } # => true
    #   F? { nil }   # => true
    #
    # @example message is given
    #
    #   F?( "computers do not doublethink" ) { 2 + 2 == 5 } # => true
    #
#   def F? message = nil, &block
#     not T? message, &block
#   end

    ##
    # Asserts that one of the given
    # kinds of exceptions is raised
    # when the given block is executed.
    #
    # @return
    #
    #   If the block raises an exception,
    #   then that exception is returned.
    #
    #   Otherwise, nil is returned.
    #
    # @param [...] kinds_then_message
    #
    #   Exception classes that must be raised by the given block, optionally
    #   followed by a message to show in the report if this assertion fails.
    #
    #   If no exception classes are given, then
    #   StandardError is assumed (similar to
    #   how a plain 'rescue' statement without
    #   any arguments catches StandardError).
    #
    # @example no exceptions given
    #
    #   E { }       # fails
    #   E { raise } # passes
    #
    # @example single exception given
    #
    #   E(ArgumentError) { raise ArgumentError }
    #   E(ArgumentError, "argument must be invalid") { raise ArgumentError }
    #
    # @example multiple exceptions given
    #
    #   E(SyntaxError, NameError) { eval "..." }
    #   E(SyntaxError, NameError, "string must compile") { eval "..." }
    #
#   def E *kinds_then_message, &block
#     assert_raise :assert, *kinds_then_message, &block
#   end

    ##
    # Asserts that one of the given kinds of exceptions
    # is not raised when the given block is executed.
    #
    # @return (see Attest.E)
    #
    # @param kinds_then_message (see Attest.E)
    #
    # @example no exceptions given
    #
    #   E! { }       # passes
    #   E! { raise } # fails
    #
    # @example single exception given
    #
    #   E!(ArgumentError) { raise ArgumentError } # fails
    #   E!(ArgumentError, "argument must be invalid") { raise ArgumentError }
    #
    # @example multiple exceptions given
    #
    #   E!(SyntaxError, NameError) { eval "..." }
    #   E!(SyntaxError, NameError, "string must compile") { eval "..." }
    #
#   def E! *kinds_then_message, &block
#     assert_raise :negate, *kinds_then_message, &block
#   end

    ##
    # Returns true if one of the given kinds of
    # exceptions is raised when the given block
    # is executed.  Otherwise, returns false.
    #
    # @param [...] kinds_then_message
    #
    #   Exception classes that must be raised by
    #   the given block, optionally followed by
    #   a message that is completely ignored.
    #
    #   If no exception classes are given, then
    #   StandardError is assumed (similar to
    #   how a plain 'rescue' statement without
    #   any arguments catches StandardError).
    #
    # @example no exceptions given
    #
    #   E? { }       # => false
    #   E? { raise } # => true
    #
    # @example single exception given
    #
    #   E?(ArgumentError) { raise ArgumentError } # => true
    #
    # @example multiple exceptions given
    #
    #   E?(SyntaxError, NameError) { eval "..." } # => true
    #   E!(SyntaxError, NameError, "string must compile") { eval "..." }
    #
#   def E? *kinds_then_message, &block
#     assert_raise :sample, *kinds_then_message, &block
#   end

    ##
    # Asserts that the given symbol is thrown
    # when the given block is executed.
    #
    # @return
    #
    #   If a value is thrown along
    #   with the expected symbol,
    #   then that value is returned.
    #
    #   Otherwise, nil is returned.
    #
    # @param [Symbol] symbol
    #
    #   Symbol that must be thrown by the given block.
    #
    # @param message (see Attest.T)
    #
    # @example no message given
    #
    #   C(:foo) { throw :foo, 123 } # passes, => 123
    #   C(:foo) { throw :bar, 456 } # fails,  => 456
    #   C(:foo) { }                 # fails,  => nil
    #
    # @example message is given
    #
    #   C(:foo, ":foo must be thrown") { throw :bar, 789 } # fails, => nil
    #
#   def C symbol, message = nil, &block
#     assert_catch :assert, symbol, message, &block
#   end

    ##
    # Asserts that the given symbol is not
    # thrown when the given block is executed.
    #
    # @return nil, always.
    #
    # @param [Symbol] symbol
    #
    #   Symbol that must not be thrown by the given block.
    #
    # @param message (see Attest.T)
    #
    # @example no message given
    #
    #   C!(:foo) { throw :foo, 123 } # fails,  => nil
    #   C!(:foo) { throw :bar, 456 } # passes, => nil
    #   C!(:foo) { }                 # passes, => nil
    #
    # @example message is given
    #
    #   C!(:foo, ":foo must be thrown") { throw :bar, 789 } # passes, => nil
    #
#   def C! symbol, message = nil, &block
#     assert_catch :negate, symbol, message, &block
#   end

    ##
    # Returns true if the given symbol is thrown when the
    # given block is executed.  Otherwise, returns false.
    #
    # @param symbol (see Attest.C)
    #
    # @param message (see Attest.T?)
    #
    # @example no message given
    #
    #   C?(:foo) { throw :foo, 123 } # => true
    #   C?(:foo) { throw :bar, 456 } # => false
    #   C?(:foo) { }                 # => false
    #
    # @example message is given
    #
    #   C?(:foo, ":foo must be thrown") { throw :bar, 789 } # => false
    #
#   def C? symbol, message = nil, &block
#     assert_catch :sample, symbol, message, &block
#   end
