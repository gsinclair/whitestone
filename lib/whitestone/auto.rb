# Provides painless, automatic configuration of Whitestone.
#
# Simply require() this file and Whitestone will be available for use anywhere
# in your program and will execute all tests before your program exits.

require 'whitestone'

class Object
  include Whitestone
end

at_exit do
  Whitestone.run

  # reflect number of failures in exit status
  stats = Whitestone.stats
  fails = stats[:fail] + stats[:error]

  exit [fails, 255].min
end
