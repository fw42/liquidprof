require "test_helper.rb"

class SomeTestClass
  def foo(*args)
    return *args
  end
end

class LiquidProfTest < Minitest::Test
  def test_hooking_and_unhooking_works
    called = false
    LiquidProf::Profiler.hook(:foo, SomeTestClass) do |node, method, args|
      called = true
      args.reverse!
      method.(*args)
    end
    obj = SomeTestClass.new
    assert_equal [3,2,1], obj.foo(1,2,3)
    assert called
    LiquidProf::Profiler.unhook(:foo, SomeTestClass)
    assert_equal [1,2,3], obj.foo(1,2,3)
  end

  EXAMPLES = [
    [ Liquid::Variable, "{{ 'foo' }}", 3 ],
    [ Liquid::Assign, "{% assign foo = 'bar' %}", 0 ],
    [ Liquid::Variable, "{% assign foo = 'bar' %} {{ foo }}", 3 ],
    [ Liquid::Assign, "{% assign foo = 'bar' %} {{ foo }}", 0 ],
    [ Liquid::Raw, "{% raw %} {{ 'foo' }} {% endraw %}", 13 ],
    [ Liquid::Variable, "{% raw %} {{ 'foo' }} {% endraw %}", 0, false ],
  ]

  EXAMPLES.each_with_index do |example, index|
    define_method "test_#{example[0]}_#{index}_stats_are_sound" do
      prof = profile(example[1])
      stats = get_stats_for_tag(prof, example[0])
      assert example[3] == false ? 0 : 1, stats.length
      assert_stats 1, 1, example[2], stats
    end
  end

  private

  def get_stats_for_tag(prof, tag)
    stats = []
    LiquidProf::Profiler.dfs(prof.templates.first.root) do |node, pos|
      if node.class == tag
        stats << node
      end
    end
    stats.uniq.map{ |node| prof.stats[node] }
  end

  def assert_stats(nodes, calls, length, stats)
    stats.each do |stat|
      assert_equal calls, stat[:calls][:raw][0]
      assert_equal length, stat[:lengths][:raw][0]
    end
  end
end
