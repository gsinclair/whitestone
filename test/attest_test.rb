
# Dfect's original test file, with Attest's extra assertions added (Eq, Mt, N).
# 
# Some of the original tests have been commented out, with an explanation.
# These will probably be removed later on, but not before committing the reason
# for their removal.
#
# Tests that contain custom error messages have been removed because this
# facility has been removed from Attest.

D 'T()' do
  T { true   }
  T { !false }
  T { !nil   }

  T { 0 } # zero is true in Ruby! :)
  T { 1 }

  # The following Dfect behaviour has been removed in Attest.
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

def foo
  raise StandardError
end

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
  # E!(SyntaxError, 'must not raise SyntaxError') { raise ArgumentError }

  D 'allows block to not raise anything' do
    E!(SyntaxError) {}
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

# Attest doesn't use YAML output; this test is no longer relevant.
#
# D 'YAML must be able to serialize a class' do
#   T { SyntaxError.to_yaml == "--- SyntaxError\n" }
# end

D 'insulated root-level describe' do
  @insulated = :insulated
  non_closured = :non_closured
end

closured = :closured

D 'another insulated root-level describe' do
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

S :knowledge do
  @sharing_is_fun = :share_knowledge
end

S :money do
  @sharing_is_fun = :share_money
end

D 'share knowledge' do
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

D 'share money' do
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

#E 'injecting shared block outside of a test' do
E {
  # It's an error to inject a shared block outside of a test.
  S :knowledge
}

  # Cancelling this test because it prevents others in the directory from being run.
xD 'stoping #run' do
  Attest.stop
  raise 'this must not be reached!'
end
