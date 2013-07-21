require 'rake/testtask'
require 'rubygems/package_task'

gemspec = eval(File.read('liquidprof.gemspec'))
Gem::PackageTask.new(gemspec) do |pkg|
  pkg.gem_spec = gemspec
end

desc "Build the gem and release it to rubygems.org"
task :release => :gem do
  sh "gem push pkg/liquid-#{gemspec.version}.gem"
end

Rake::TestTask.new do |t|
  t.libs << 'test'
end

desc "Run tests"
task :default => :test
