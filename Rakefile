require 'rake/testtask'
require 'rubygems/package_task'

gemspec = eval(File.read('liquidprof.gemspec'))
Gem::PackageTask.new(gemspec) do |pkg|
  pkg.gem_spec = gemspec
end

desc "Build the gem and release it to rubygems.org"
task :release => :gem do
  sh "gem push pkg/liquidprof-#{gemspec.version}.gem"
end

Rake::TestTask.new(:test) do |t|
  t.libs << 'test'
end

Rake::TestTask.new(:test_liquid) do |t|
  t.test_files = FileList['test/liquid/test/liquid/*_test.rb']
  t.libs << 'test/liquid/test'
end

desc "Run tests"
task :default => :test
