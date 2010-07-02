require 'rake'  # FileList
Gem::Specification.new do |spec|
  spec.name = "attest"
  spec.version = "1.0.0"
  spec.summary = "Unit testing library (fork of sunaku/dfect v2.1.0)"
  spec.description = <<-EOF
    Unit testing library with colourful, helpful error messages,
    small testing code footprint, good debugger integration.
  EOF
  spec.email = "gsinclair@gmail.com"
  spec.homepage = "http://github.com/gsinclair/dfect"
  spec.authors = ['Suraj N. Karaputi', 'Gavin Sinclair']

  spec.files = FileList['lib/**/*.rb', '[A-Z]*', 'test/**/*'].to_a
  spec.executables << 'attest'
  spec.test_files = FileList['test/**/*'].to_a
  spec.has_rdoc = false

  spec.add_dependency("term-ansicolor", ">= 1.0")
  spec.add_dependency("differ", ">= 0.1")
  spec.required_ruby_version = '>= 1.8.6'    # Not sure about this.
end
