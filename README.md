LiquidProf
==========

LiquidProf is a simple profiler for the [Liquid](https://github.com/Shopify/liquid)
templating language, inspired by [rblineprof](https://github.com/tmm1/rblineprof).

This is work in progress and not really ready to use!

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
puts LiquidProf::AsciiReporter.report(prof)
```

will generate a report like this:

```
    +----------------------+
 1  |      1x, 0.05ms, 0B  |  {% assign user = "flo" %}
 2  |                      |
 3  |      1x, 0.05ms, 3B  |  Hello {{ user }},
 4  |                      |
 5  |                      |  this is an example Liquid template.
 6  |                      |
 7  |      1x, 0.00ms, 0B  |  {% comment %}
 8  |      0x, 0.00ms, 0B  |  {% assign user = "florian" %}
 9  |                      |  {% endcomment %}
10  |                      |
11  |      1x, 4.97ms, 0B  |  {% capture test %}
12  |      1x, 0.02ms, 0B  |    {% assign c = 0 %}
13  |   1x, 4.92ms, 1.53K  |    {% for i in (1..10) %}
14  |    10x, 0.16ms, 60B  |      {% if i % 2 == 0 %} even {% endif %}
15  |  10x, 4.45ms, 1.34K  |      {% for j in (i..10) %}
16  |   55x, 0.09ms, 100B  |        {% increment c %}: {{ i }} + {{ j }} = {{ i + j }}
    |    55x, 0.55ms, 56B  |
    |    55x, 0.51ms, 65B  |
    |    55x, 0.52ms, 56B  |
17  |                      |      {% endfor %}
18  |                      |    {% endfor %}
19  |                      |  {% endcapture %}
20  |                      |
21  |      1x, 0.01ms, 1B  |  {{ c }}: {{ test }}
    |   1x, 0.01ms, 1.54K  |
22  |                      |
23  |      1x, 0.01ms, 3B  |  Bye {{ user }}.
    +----------------------+
            5.19ms, 1.60K
```

TODO
----
* Fancy HTML reporter, possibly using [highlight.js](http://softwaremaniacs.org/soft/highlight/en/description/)

Tests
-----
* Run ```./add_liquid_tests.sh <path_to_liquid_git_repo>```
* Run ```rake test``` to run LiquidProf tests
* Run ```rake test_liquid``` to run Liquid tests with LiquidProf profiling enabled

Bugs
----
* LiquidProf is not thread-safe in some situations. Enabling/disabling the profiler in one thread will do so for all other threads as well.
