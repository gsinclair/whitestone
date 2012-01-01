# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "attest/version"

Gem::Specification.new do |s|
  s.name        = "attest"
  s.version     = Attest::VERSION
  s.authors     = ["Gavin Sinclair"]
  s.email       = ["gsinclair@gmail.com"]
  s.homepage    = "http://gsinclair.github.com/attest.html"
  s.summary     = "Unit testing library (fork of sunaku/dfect v2.1.0)"
  s.description = <<-EOF
    Unit testing library with colourful, helpful error messages,
    small testing code footprint, good debugger integration.
    (Derivative work of Dfect.)
  EOF

  s.rubyforge_project = ""

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_runtime_dependency "col", ">= 1.0.1"
  s.add_runtime_dependency "differ", "~> 0.1"

  s.add_development_dependency "bundler"

  s.required_ruby_version = '>= 1.8.6'    # Not sure about this.
end
