lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'liquidprof/version'

Gem::Specification.new do |spec|
  spec.name          = "liquidprof"
  spec.version       = LiquidProf::VERSION
  spec.authors       = ["Florian Weingarten"]
  spec.email         = ["flo@hackvalue.de"]
  spec.description   = %q{Liquid profiler}
  spec.summary       = %q{Performance profiler for the Liquid templating language}
  spec.homepage      = "https://github.com/fw42/liquidprof"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "liquid", "~> 2.5"
  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "minitest", "~> 5.0"
end
