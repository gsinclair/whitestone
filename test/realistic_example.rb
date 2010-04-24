
require 'attest/auto'

# This file contains a realistic example of unit testing using attest.  The
# code contains bugs which the tests reveal.

# - something with a complex #inspect and/or #to_s (or perhaps #html)
# - something that takes direct input and gives direct output
#   (i.e. no need for reading file or interacting with other objects)
# - something involving some parsing, like RGeom's types
# - something involving a data store (index), especially if it means
#   that setup is required before the tests
# - add_xxx(...)
# - maybe take a test from an existing project (RubyGems?) and convert
#   it to attest
# - RGeom::Label ?
# - RGeom::Point, modified to store points like :A itself ?
#   - and RGeom::Vertex to boot?
# - something that takes a nested data structure (arrays inside hashes
#   inside...) and generates meaningful summary data
# - look at existing unit testing tutorials on the net
