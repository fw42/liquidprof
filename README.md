LiquidProf
==========

LiquidProf is a simple profiler for the [Liquid](https://github.com/Shopify/liquid)
templating language, inspired by [rblineprof](https://github.com/tmm1/rblineprof).

Build status (master): [![Build Status](https://travis-ci.org/fw42/liquidprof.png)](https://travis-ci.org/fw42/liquidprof)

Installation
------------
* ```gem install liquidprof``` (https://rubygems.org/gems/liquidprof)

Profiling
---------

Wrapping your ```parse()``` and ```render()``` calls in a
```LiquidProf::Profiler.profile``` block will profile the containing
templates and return a Profiler object which encapsulates the profiling
results of each of the templates.

```ruby
prof = LiquidProf::Profiler.profile(10) do
  template1 = Liquid::Template.parse(str1)
  output1 = template1.render()

  template2 = Liquid::Template.new
  template2.parse(str2)
  output2 = template2.render()
end
```

A bit more explicit:

```ruby
prof = LiquidProf::Profiler.start
template = Liquid::Template.parse(str)
prof.profile(template, 10)
LiquidProf::Profiler.stop
```

Reporting
---------
```ruby
puts LiquidProf::AsciiReporter.report(prof, template)
```

will generate a report like this:

```

```

TODO
----
* Fancy HTML reporter

Tests
-----
* Run ```./add_liquid_tests.sh <path_to_liquid_git_repo>```
* Run ```rake test``` to run LiquidProf tests
* Run ```rake test_liquid``` to run Liquid tests with LiquidProf profiling enabled
