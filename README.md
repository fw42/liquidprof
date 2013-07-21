LiquidProf
==========

LiquidProf is a simple profiler for the [Liquid](https://github.com/Shopify/liquid)
templating language, inspired by [rblineprof](https://github.com/tmm1/rblineprof).

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
 1  |     1x, 0.05ms, 0B  |  {% assign user = "flo" %}
 2  |                     |
 3  |     1x, 0.05ms, 3B  |  Hello {{ user }},
 4  |                     |
 5  |                     |  this is an example of Liquid.
 6  |                     |
 7  |     1x, 0.00ms, 0B  |  {% comment %}
 8  |     0x, 0.00ms, 0B  |  {% assign user = "florian" %}
 9  |                     |  {% endcomment %}
10  |                     |
11  |     1x, 5.06ms, 0B  |  {% capture test %}
12  |     1x, 0.02ms, 0B  |    {% assign c = 0 %}
13  |     1x, 5.01ms, 1K  |    {% for i in (1..10) %}
14  |   10x, 0.17ms, 60B  |      {% if i % 2 == 0 %} even {% endif %}
15  |    10x, 4.52ms, 1K  |      {% for j in (i..10) %}
16  |  55x, 0.09ms, 100B  |        {% increment c %}: {{ i }} + {{ j }} = {{ i + j }}
    |   55x, 0.54ms, 56B  |
    |   55x, 0.52ms, 65B  |
    |   55x, 0.52ms, 56B  |
17  |                     |      {% endfor %}
18  |                     |    {% endfor %}
19  |                     |  {% endcapture %}
20  |                     |
21  |     1x, 0.01ms, 1B  |  {{ c }}: {{ test }}
    |     1x, 0.01ms, 1K  |
22  |                     |
23  |     1x, 0.01ms, 3B  |  Bye {{ user }}.
```

TODO
----
* Fancy HTML reporter
