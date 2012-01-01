
# This file looks at the visibility of classes, modules, methods, constants and
# instance variables across insulated and non-insulated boundaries.
#
# Only T and F assertions are used so that Dfect's behaviour can be tested as
# well.

module Insulation
  def answer
    :foo
  end
end

def ruby_version
  @__ruby_version =
    case RUBY_VERSION
    when /^1.8/ then :v18
    when /^1.9/ then :v19
    else raise "Unknown version of Ruby: #{RUBY_VERSION}"
    end
end

def D18(text, &block)
  if ruby_version == :v18
    D text, &block
  end
end

def D19(text, &block)
  if ruby_version == :v19
    D text, &block
  end
end

D "Modules" do
  D "We can 'extend Insulation' in a non-insulated test" do
    extend Insulation
    T { answer() == :foo }

    D "we can use Insulation in a sub-test" do
    T { answer() == :foo }
    end

    D! "but we can't use Insulation in an insulated sub-test" do
      E(NoMethodError) { answer() == :foo }
    end
  end

  D "We can still use Insulation in a different (non-insulated) test" do
    T { answer() == :foo }
  end

  D! "We CAN'T use Insulation in a different (insulated) test" do
    E(NoMethodError) { answer() == :foo }
  end

  D! "If we 'extend Insulation' in an insulated test..." do
    extend Insulation
    T { answer() == :foo }
    D "...we can use Insulation in a sub-test" do
      T { answer() == :foo }
    end
  end
end  # "Modules"

D "Modules (again)" do
  E(NoMethodError) { answer() == :foo }   # just checking...
  D "[nesting]" do
    D "[nesting]" do
      D "A module inclusion in a deeply nested test..." do
        extend Insulation
      end
    end
  end
  D "...can be used at an outer level" do
    T { answer() == :foo }
  end
  D "(because there was no insulation anywhere)" do end
end


D "Methods" do
  D "We can define a method (times2) even in a non-insulated test" do
    def times2(x) x*2 end
    T { times2(14) == 28 }
  end

  D "We can use 'times2' in a sibling test..." do
    T { times2(-5) == -10 }
    D "...and in a non-insulated sub-test" do
      T { times2(916) == 1832 }
    end
    D! "...but we CAN'T can use 'times2' in an insulated sub-test" do
      E(NoMethodError) { times2(916) == 1832 }
    end
  end

  D "If we set up an insulated test..." do
    D! "...here..." do
      D "...and define a method (sum) ..." do
        def sum(collection) collection.inject(0) { |acc, x| acc + x } end
      end
      D "...then we can use the method in a separate test" do
        T { sum([1,4,2,-3]) == 4 }
      end
    end
    D "...but we CAN'T use the method outside of the insulated environment" do
      E(NoMethodError) { sum([10,9,8,7]) == 34 }
    end
  end
end  # "Methods"

D "Methods (again)" do
  D "We CAN'T reuse the times2 and sum in a different test" do
    E(NoMethodError) { times2(-5) == -10 }
    E(NoMethodError) { sum([5,100]) == 105 }
  end
end

D "Methods (once more)" do
  D "[nesting]" do
    D "[nesting]" do
      D "A method definition in a deeply nested test..." do
        def empty_string?(str) str.strip.size == 0 end
      end
    end
  end
  D "...can be used at an outer level" do
    T { empty_string? "   \t\n " }
    F { empty_string? " faf fsdf fd " }
  end
  D "(because there was no insulation anywhere)" do end
end

D "Instance variables" do
  D "@x is defined in one test..." do
    @x = 6
  end
  D "...and is accessible in another..." do
    T { @x == 6 }
  end
  D! "...unless the test is insulated" do
    F { @x == 6 }
    D "We can reuse @x in here..." do
      @x = -1
      D "(sub-test)" do
        T { @x == -1 }
      end
    end
  end
  D "...and it reverts to its previous value outside the insulated area" do
    T { @x == 6 }
  end
end

D "Instance variables (again) " do
  D! "@y is defined in an insulated test..." do
    @y = 10
    D "...and is accessible in a non-insulated subtest" do
      T { @y == 10 }
    end
    D! "...but is not accessible in an insulated subtest" do
      F { @y == 10 }
    end
  end
  D "...but is not accessible in a sibling test" do
    F { @y == 10 }
  end
end

D "An insulated test..." do
  D.<< { @a = 32 }
  D.<  { @z = 99 }
  D! "...does NOT see an instance variable defined in the setup blocks" do
    F { @a == 32 }
    F { @z == 99 }
  end
end

# Given that all the above tests pass (in Whitestone and Dfect), here are my
# conclusions:
#  * Class and constant definitions are globally accessible and are not affected
#    by insulation.
#     - This used to be tested differently in 1.8 and 1.9, but in 1.9.3 the
#       difference appears to have vanished, so I removed the tests.
#  * Methods definitions (whether direct or via 'extend Foo') are sealed by
#    insulation.  Nothing gets in or out.
#  * The same is true for instance variables.
#
# The reason insulation is effective against methods and instance variables is
# that they rely on the value of _self_ to be resolved.  An insulated
# environment introduces a new value of _self_.  This is shown in the following
# (paraphrased) Whitestone code:
#
#     def run_test(test)
#       if test.insulated?
#         Object.new.instance_eval(&test.block)
#       else
#         test.block.call
#       end
#     end

