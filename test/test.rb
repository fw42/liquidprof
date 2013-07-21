require "test_helper.rb"

class SomeTestClass
  def foo(*args)
    return *args
  end
end


def assert_block_syntax()
end

def assert_stats_sound(prof, document, runs=1)
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

  def test_woot
    prof, template = profile("{{ 'foo' }}")
  end
end
