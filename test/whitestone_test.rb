
# Dfect's original test file, with Whitestone's extra assertions added (Eq, Mt, N).
# 
# Some of the original tests have been commented out, with an explanation.
# These will probably be removed later on, but not before committing the reason
# for their removal.
#
# Tests that contain custom error messages have been removed because this
# facility has been removed from Whitestone.

D "Assertion classes" do
  D 'T()' do
    T { true   }
    T { !false }
    T { !nil   }

    T { 0 } # zero is true in Ruby! :)
    T { 1 }

    # The following Dfect behaviour has been removed in Whitestone.
    # I prefer assertions (of any kind) to return true or false.
    # Comment kept here in case there's a good reason for the Dfect
    # behaviour that I'm not currently aware of.
    #
    # D 'must return block value' do
    #   inner = rand()
    #   outer = T { inner }
    #   
    #   T { outer == inner }
    # end
  end

  D 'T!()' do
    T! { !true }
    T! { false }
    T! { nil   }

    # See comment above.
    #
    # D 'must return block value' do
    #   inner = nil
    #   outer = T! { inner }
    #    
    #   T { outer == inner }
    # end
  end

  D 'T?()' do
    T { T? { true  } }
    F { T? { false } }
    F { T? { nil   } }

    # See above comment.  This one passes anyway, but it's not behaviour I care
    # to specify.
    #
    # D 'must not return block value' do
    #   inner = rand()
    #   outer = T? { inner }
    #    
    #   F { outer == inner }
    #   T { outer == true }
    # end
  end

  D 'F?()' do
    T { T? { true  } }
    F { T? { false } }
    F { T? { nil   } }

    # See above comment.
    #
    # D 'must not return block value' do
    #   inner = rand()
    #   outer = F? { inner }
    #    
    #   F { outer == inner }
    #   T { outer == false }
    # end
  end

  D 'Eq()' do
    Eq 5, 5
    Eq "foo", "foo"
    Eq [1,2,3,:x], [1,2,3,:x]
    Eq! "foo", 5
    Eq! 5, "foo"
    Eq! [1,2,3,:x], [1,2,3,:z]
    T { Eq? 5, 5 }
    F { Eq? 5, 6 }
  end

  D 'Mt, Mt!, Mt?' do
    Mt "foo", /foo/
    Mt /foo/, "fool"        # Order is unimportant.
    Mt "foo", /./
    Mt! "foo", /egg/
    T { Mt? "foo", /o+/ }
    D "removes color codes before checking match" do
      require 'col'
      Mt  Col["foo ", "bar"].fmt('rb,yb'), /foo bar/
      Mt! Col["foo ", "bar"].fmt('rb,yb'), /foo bat/
    end
  end

  D 'N, N!, N?' do
    N nil
    N { nil }
    N! 0
    N! { 0 }
    N! false
    N! { false }
    T { N? { nil } }
    F { N? { rand() } }
  end

  D 'Ko' do
    Ko "foo",  String
    Ko "foo",  Object
    Ko! "foo", Numeric
    Ko [1,2,3], Enumerable
    E { Ko String, "foo" }   # wrong order -- expect an error
  end

  D 'Ft' do
    D 'basic' do
      Ft 45.44332211, 45.443322110000000000001
      Ft! 109.123456, 109.123457   # These are too close to be considered
                                   # essentially equal.
    end
    D 'test values of massively differing magnitude' do
      a = 0.000000000837
      b = 0.0000000004315    # a and b are _not_ "essentially" equal
      Ft! a, b
      Ft! b, a
      c = 100.000000000000837
      d = 100.0000000000004315  # c and d _are_ "essentially" equal
      Ft  c, d
      Ft  d, c
    end
    D "anomolies like (1.1 - 1.0) does not equal 0.1" do
      Ft 1.1 - 1.0, 0.1
      Ft 1.1 - 1.0 - 0.1, 0.0
      Ft 0.1 + 0.1, 0.2
      Ft 0.2 + 0.1, 0.3  # This doesn't work when using ==
      Ft 0.3 + 0.1, 0.4
      Ft 0.4 + 0.1, 0.5
      Ft 0.5 + 0.1, 0.6
      Ft 0.6 + 0.1, 0.7
      Ft 0.7 + 0.1, 0.8  # Nor does this one
      Ft 0.8 + 0.1, 0.9
      Ft 0.9 + 0.1, 1.0
    end
    D 'integer values' do
      Ft 4,   4
      Ft 4.0, 4
      Ft 4,   4.0
      Ft -13, -13
      Ft -13.0, -13
      Ft! 4, 5
    end
    D 'zero' do
      Ft 0,   0
      Ft 0,   0.0
      Ft 0.0, 0
      Ft 0.0, 0.0
      Ft 0.0, -1.1102230246251565e-16
      Ft -1.1102230246251565e-16, 0.0
    end
    D 'numbers near zero' do
      Ft! 0, 0.001
      Ft! 0, 0.0001
      Ft! 0, 0.00001
      Ft! 0, 0.000001
      Ft! 0, 0.0000001
      Ft! 0, 0.00000001
      Ft! 0, 0.000000001
      Ft! 0, 0.0000000001
      Ft! 0, 0.00000000001
      Ft! 0, 0.000000000001
      Ft! 0, 0.0000000000001
      Ft! 0, 0.00000000000001
      Ft  0, 0.000000000000001      # This is the first float that is
      Ft  0, 0.0000000000000001     # essentially equal to zero.
      Ft  0, 0.00000000000000001
      Ft  0, 0.000000000000000001
    end
    D '(near) equal and negative' do
      a = -2.000000000051298352
      b = -2.000000000051298336
      Ft a, b
      Ft b, a
    end
    D "13th digit differs: not equal enough" do
      Ft! 1.234567890123e50,  1.23456789122e50
      Ft! 1.234567890123e40,  1.23456789122e40
      Ft! 1.234567890123e30,  1.23456789122e30
      Ft! 1.234567890123e20,  1.23456789122e20
      Ft! 1.234567890123e10,  1.23456789122e10
      Ft! 1.234567890123e0,   1.23456789122e0
      Ft! 1.234567890123e-10, 1.23456789122e-10
      Ft! 1.234567890123e-20, 1.23456789122e-20
      Ft! 1.234567890123e-30, 1.23456789122e-30
      Ft! 1.234567890123e-40, 1.23456789122e-40
    end
    D "14th digit differs: equal enough" do
      Ft 1.2345678901234e90,  1.2345678901233e90
      Ft 1.2345678901234e90,  1.2345678901234e90
      Ft 1.2345678901234e90,  1.2345678901235e90
      Ft 1.2345678901234e50,  1.2345678901233e50
      Ft 1.2345678901234e50,  1.2345678901234e50
      Ft 1.2345678901234e50,  1.2345678901235e50
      Ft 1.2345678901234e10,  1.2345678901233e10
      Ft 1.2345678901234e10,  1.2345678901234e10
      Ft 1.2345678901234e10,  1.2345678901235e10
      Ft 1.2345678901234e0,   1.2345678901233e0
      Ft 1.2345678901234e0,   1.2345678901234e0
      Ft 1.2345678901234e0,   1.2345678901235e0
      Ft 1.2345678901234e-10, 1.2345678901233e-10
      Ft 1.2345678901234e-10, 1.2345678901234e-10
      Ft 1.2345678901234e-10, 1.2345678901235e-10
      Ft 1.2345678901234e-50, 1.2345678901233e-50
      Ft 1.2345678901234e-50, 1.2345678901234e-50
      Ft 1.2345678901234e-50, 1.2345678901235e-50
      Ft 1.2345678901234e-90, 1.2345678901233e-90
      Ft 1.2345678901234e-90, 1.2345678901234e-90
      Ft 1.2345678901234e-90, 1.2345678901235e-90
      D "but it can only be off by 1" do
        Ft! 1.2345678901234e90, 1.2345678901231e90
        Ft! 1.2345678901234e90, 1.2345678901232e90
        Ft! 1.2345678901234e90, 1.2345678901236e90
        Ft! 1.2345678901234e90, 1.2345678901237e90
        Ft! 1.2345678901234e10, 1.2345678901231e10
        Ft! 1.2345678901234e10, 1.2345678901232e10
        Ft! 1.2345678901234e10, 1.2345678901236e10
        Ft! 1.2345678901234e10, 1.2345678901237e10
        Ft! 1.2345678901234e-10, 1.2345678901231e-10
        Ft! 1.2345678901234e-10, 1.2345678901232e-10
        Ft! 1.2345678901234e-10, 1.2345678901236e-10
        Ft! 1.2345678901234e-10, 1.2345678901237e-10
        Ft! 1.2345678901234e-90, 1.2345678901231e-90
        Ft! 1.2345678901234e-90, 1.2345678901232e-90
        Ft! 1.2345678901234e-90, 1.2345678901236e-90
        Ft! 1.2345678901234e-90, 1.2345678901237e-90
      end
    end
    D "Ft does not allow epsilon argument" do
      E(AssertionSpecificationError) { Ft? 3.14159265, 3.1415, 0.01 }
    end
  end

  D 'Id' do
    Id 5, 5
    Id (x = "foo"), x
    Id! "foo", "foo"
    T { Id? x, x }
    a = [1,2,3]
    b = a
    Id a, b
    Id a, a
    Id b, b
    Id! a, a.dup
  end
end  # Assertion methods

def foo
  raise StandardError, "Error to help test E"
end

D "Exceptions: E, E!, E?" do
  D 'E()' do
    E { foo }
    E(StandardError) { foo }
    # There's no longer provisions for specifying an error message.
    # E(SyntaxError, 'must raise SyntaxError') { raise SyntaxError }

    D 'forbids block to not raise anything' do
      F { E? {} }
    end

    # This seems wrong to me.  The block will raise a SyntaxError.  We can't
    # ignore that; it has to be reported to the user.  Therefore, it can't
    # appear like that in a unit test.
    #
    # This reasoning can be called "Comment E" for reference below.
    #
    # D 'forbids block to raise something unexpected' do
    #   F { E?(ArgumentError) { raise SyntaxError } }
    # end

    D 'defaults to StandardError when no kinds specified' do
      E { raise StandardError }
      E { raise }
    end

    # See Comment E above.
    #
    # D 'does not default to StandardError when kinds are specified' do
    #   F { E?(SyntaxError) { raise } }
    # end

    D 'allows nested rescue' do
      E ArgumentError do
        begin
          raise LoadError
        rescue LoadError
        end

        raise rescue nil

        raise ArgumentError
      end
    end
  end

  D 'E!()' do
    # See Comment E above.  Also, I'm not sure E! should actually be able to
    # specify an Exception type.  Surely the assertion is that it doesn't raise
    # anything.
    #
    # E!(SyntaxError) { raise ArgumentError }

    D 'allows block to not raise anything' do
      E!() {}
      E!(ArgumentError) {}
    end

    # See Comment E.
    #
    # D 'allows block to raise something unexpected' do
    #   T { not E?(ArgumentError) { raise SyntaxError } }
    # end
    #  
    # D 'defaults to StandardError when no kinds specified' do
    #   E! { raise LoadError }
    # end
    #  
    # D 'does not default to StandardError when kinds are specified' do
    #   T { not E?(SyntaxError) { raise } }
    # end

  end

  D 'E?()' do
    T E?(ArgumentError) { raise ArgumentError }
    F E?(ArgumentError) { 1 + 1 }
    # F E?(SyntaxError) { raise ArgumentError }     Comment E
  end
end  # "Exceptions: E, E!, E?"

D "Catch: C, C!, C?" do
  D 'C()' do
    C(:foo) { throw :foo }
    C(:foo) { throw :foo }

    D 'forbids block to not throw anything' do
      F { C?(:bar) {} }
    end

    D 'forbids block to throw something unexpected' do
      F { C?(:bar) { throw :foo } }
    end

    D 'allows nested catch' do
      C :foo do
        catch :bar do
          throw :bar
        end

        throw :foo
      end
    end

    # Like other assertions, C returns true or false.  Whatever value is thrown
    # is lost.  If I need to test that, I'm happy to do so more directly.
    #
    # D 'returns the value thrown along with symbol' do
    #   inner = rand()
    #   outer = C(:foo) { throw :foo, inner }
    #   T { outer == inner }
    # end
  end

  D 'Whitestone.caught_value' do
    def foo
      throw :abc, 5
    end
    def bar
      throw :abc
    end
    C(:abc) { foo }
    Eq Whitestone.caught_value, 5
    C(:abc) { bar }
    Eq Whitestone.caught_value, nil
    C?(:abc) { foo }
    Eq Whitestone.caught_value, 5
    C!(:def) { bar }
    Eq Whitestone.caught_value, nil
    C!(:def) { foo }
    Eq Whitestone.caught_value, nil    # Not updated in this instance.
  end

  D 'C!()' do
    C!(:bar) { throw :foo }
    C!(:bar) { throw :foo }

    D 'allows block to not throw anything' do
      C!(:bar) {}
    end

    D 'allows block to throw something unexpected' do
      T { not C?(:bar) { throw :foo } }
    end

    D 'allows nested catch' do
      C! :bar do
        catch :moz do
          throw :moz
        end

        throw :foo
      end
    end

    # As per comment above, I have no interest in the value thrown.
    #
    # D 'does not return the value thrown along with symbol' do
    #   inner = rand()
    #   outer = C!(:foo) { throw :bar, inner }
    #    
    #   F { outer == inner }
    #   T { outer == nil   }
    # end
  end

  D 'C?()' do
    T C?(:foo) { throw :foo }
    F C?(:bar) { throw :foo }
  end
end  # "Catch: C, C!, C?"

D 'D' do
  D 'D()' do
    history = []

    D .<< { history << :before_all  }
    D .<  { history << :before_each }
    D .>  { history << :after_each  }
    D .>> { history << :after_all   }

    D 'first nesting' do
      T { history.select {|x| x == :before_all  }.length == 1 }
      T { history.select {|x| x == :before_each }.length == 1 }
      F { history.select {|x| x == :after_each  }.length == 1 }
      T { history.select {|x| x == :after_all   }.length == 0 }
    end

    D 'second nesting' do
      T { history.select {|x| x == :before_all  }.length == 1 }
      T { history.select {|x| x == :before_each }.length == 2 }
      T { history.select {|x| x == :after_each  }.length == 1 }
      T { history.select {|x| x == :after_all   }.length == 0 }
    end

    D 'third nesting' do
      T { history.select {|x| x == :before_all  }.length == 1 }
      T { history.select {|x| x == :before_each }.length == 3 }
      T { history.select {|x| x == :after_each  }.length == 2 }
      T { history.select {|x| x == :after_all   }.length == 0 }
    end

    D 'fourth nesting' do
      D .<< { history << :nested_before_all  }
      D .<  { history << :nested_before_each }
      D .>  { history << :nested_after_each  }
      D .>> { history << :nested_after_all   }

      nested_before_each = 0

      D .< do
        # outer values remain the same for this nesting
        T { history.select {|x| x == :before_all  }.length == 1 }
        T { history.select {|x| x == :before_each }.length == 4 }
        T { history.select {|x| x == :after_each  }.length == 3 }
        T { history.select {|x| x == :after_all   }.length == 0 }

        nested_before_each += 1
        T { history.select {|x| x == :nested_before_each }.length == nested_before_each }
      end

      D 'first double-nesting' do
        T { history.select {|x| x == :nested_before_all  }.length == 1 }
        T { history.select {|x| x == :nested_before_each }.length == 1 }
        F { history.select {|x| x == :nested_after_each  }.length == 1 }
        T { history.select {|x| x == :nested_after_all   }.length == 0 }
      end

      D 'second double-nesting' do
        T { history.select {|x| x == :nested_before_all  }.length == 1 }
        T { history.select {|x| x == :nested_before_each }.length == 2 }
        T { history.select {|x| x == :nested_after_each  }.length == 1 }
        T { history.select {|x| x == :nested_after_all   }.length == 0 }
      end

      D 'third double-nesting' do
        T { history.select {|x| x == :nested_before_all  }.length == 1 }
        T { history.select {|x| x == :nested_before_each }.length == 3 }
        T { history.select {|x| x == :nested_after_each  }.length == 2 }
        T { history.select {|x| x == :nested_after_all   }.length == 0 }
      end
    end
  end

  D 'D.<() must allow inheritance checking when called without a block' do
    F { D < Kernel }
    F { D < Object }
    F { D < Module }
    T { D.class == Module }

    c = Class.new { include D }
    T { c < D }
  end

  # Whitestone doesn't use YAML output; this test is no longer relevant.
  #
  # D 'YAML must be able to serialize a class' do
  #   T { SyntaxError.to_yaml == "--- SyntaxError\n" }
  # end

  D! 'insulated root-level describe' do
    @insulated = :insulated
    non_closured = :non_closured
  end

  closured = :closured

  D! 'another insulated root-level describe' do
    # without insulation, instance variables
    # from previous root-level describe
    # environments will spill into this one
    F { defined? @insulated }
    F { @insulated == :insulated }

    # however, this insulation must
    # not prevent closure access to
    # surrounding local variables
    T { defined? closured }
    T { closured == :closured }

    # except local variables defined
    # within another insulated environment
    F { defined? non_closured }
    E(NameError) { non_closured }

    @insulated_again = :insulated_again

    D 'non-insulated nested describe' do
      D 'inherits instance variables' do
        T { defined? @insulated_again }
        T { @insulated_again == :insulated_again }
      end

      D 'inherits instance methods' do
        E!(NoMethodError) { instance_level_helper_method }
        T { instance_level_helper_method == :instance_level_helper_method }
      end

      D 'inherits class methods' do
        E!(NoMethodError) { self.class_level_helper_method }
        T { self.class_level_helper_method == :class_level_helper_method }

        E!(NoMethodError) { class_level_helper_method }
        T { class_level_helper_method == self.class_level_helper_method }
      end

      @non_insulated_from_nested = :non_insulated_from_nested
    end

    D! 'nested but explicitly insulated describe' do
      D 'does not inherit instance variables' do
        F { defined? @insulated_again }
        F { @insulated_again == :insulated_again }
      end

      D 'does not inherit instance methods' do
        E(NameError) { instance_level_helper_method }
      end

      D 'does not inherit class methods' do
        E(NoMethodError) { self.class_level_helper_method }
        E(NameError) { class_level_helper_method }
      end

      @non_insulated_from_nested = 123
    end

    D 'another non-insulated nested describe' do
      T { defined? @non_insulated_from_nested }
      T { @non_insulated_from_nested == :non_insulated_from_nested }
    end

    def instance_level_helper_method
      :instance_level_helper_method
    end

    def self.class_level_helper_method
      :class_level_helper_method
    end
  end

  D 'yet another insulated root-level describe' do
    F { defined? @insulated_again }
    F { @insulated_again == :insulated_again }

    F { defined? @non_insulated_from_nested }
    F { @non_insulated_from_nested == :non_insulated_from_nested }
  end
end  # 'D'

D 'Sharing' do
  S :knowledge do
    @sharing_is_fun = :share_knowledge
  end

  S :money do
    @sharing_is_fun = :share_money
  end

  D! 'share knowledge' do
    F { defined? @sharing_is_fun }
    S :knowledge
    T { defined? @sharing_is_fun }
    T { @sharing_is_fun == :share_knowledge }

    F { S? :power }
    S! :power do
      @sharing_is_fun = :share_power
    end
    T { S? :power }
  end

  D! 'share money' do
    F { defined? @sharing_is_fun }
    S :money
    T { defined? @sharing_is_fun }
    T { @sharing_is_fun == :share_money }

    S :power
    T { defined? @sharing_is_fun }
    T { @sharing_is_fun == :share_power }

    D! 'share knowledge inside nested but explicitly insulated describe' do
      F { defined? @sharing_is_fun }
      S :knowledge
      T { defined? @sharing_is_fun }
      T { @sharing_is_fun == :share_knowledge }
    end
  end

  D 're-sharing under a previously shared identifier' do
    E ArgumentError do
      S :knowledge do
        @sharing_is_fun = :overwrite_previous_share
      end
    end

    F { defined? @sharing_is_fun }
    F { @sharing_is_fun == :overwrite_previous_share }
  end

  D 'injecting an unshared code block' do
    E ArgumentError do
      S :foobar
    end
  end
end  # 'Sharing'

#E 'injecting shared block outside of a test' do
E {
  # It's an error to inject a shared block outside of a test.
  S :knowledge
}

  # Cancelling this test because it prevents others in the directory from being run.
xD 'stoping #run' do
  Whitestone.stop
  raise 'this must not be reached!'
end
