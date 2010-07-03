# Provides painless, automatic configuration of Attest.
#
# Simply require() this file and Attest will be available for use anywhere
# in your program and will execute all tests before your program exits.

require 'attest'

class Object
  include Attest
end

at_exit do
  Attest.run

  # reflect number of failures in exit status
  stats = Attest.stats
  fails = stats[:fail] + stats[:error]

  exit [fails, 255].min
end
