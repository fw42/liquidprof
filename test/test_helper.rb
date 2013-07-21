require 'bundler/setup'
require 'minitest/autorun'
require 'minitest/unit'
require 'minitest/pride'

$LOAD_PATH.unshift File.expand_path('../lib', File.dirname(__FILE__))
require "liquidprof"

def profile(template_str)
  profs = [*1..5].map do |i|
    assert_profile_syntax_doesnt_matter(template_str, i)
  end
  assert_profile_iterations_dont_matter(*profs.map{ |res| res.first })
  assert_raw_markup_present(profs.first.last.root)
  profs.first
end

def assert_raw_markup_present(root)
  if root.class != Liquid::Document && (root.is_a?(Liquid::Tag) || root.is_a?(Liquid::Variable))
    assert root.instance_variable_defined?(:@raw_markup)
  end

  if root.class != Liquid::Document && root.is_a?(Liquid::Block)
    assert root.instance_variable_defined?(:@raw_markup_end)
  end

  if root.respond_to?(:nodelist) && root.nodelist
    root.nodelist.each do |child|
      assert_raw_markup_present(child)
    end
  end
end

def assert_stats_equal(prof1, prof2)
  prof1 = prof1.stats.values.sort_by{ |h| h.to_s }
  prof2 = prof2.stats.values.sort_by{ |h| h.to_s }
  assert_equal prof1.length, prof2.length

  prof1.each_index do |i|
    assert_equal prof1[i][:times][:raw].length, prof2[i][:times][:raw].length
    assert_equal prof1[i][:calls], prof2[i][:calls]
    assert_equal prof1[i][:lengths], prof2[i][:lengths]
  end
end

def assert_profile_iterations_dont_matter(*profs)
  profs.each_index do |i|
    profs[i] = profs[i].stats.values.sort_by{ |h| h.to_s }
  end

  profs.first.each_index do |i|
    0.upto(profs.length-2) do |j|
      (j+1).upto(profs.length-1) do |k|
        [ :avg, :min, :max ].each do |field|
          assert_equal profs[j][i][:calls][field], profs[k][i][:calls][field]
          assert_equal profs[j][i][:lengths][field], profs[k][i][:lengths][field]
        end
      end
    end
  end
end

def assert_profile_syntax_doesnt_matter(template_str, iterations=1)
  prof1 = LiquidProf::Profiler.start
  t1 = Liquid::Template.new
  t1.parse(template_str)
  prof1.profile(t1, iterations)
  LiquidProf::Profiler.stop

  prof2 = LiquidProf::Profiler.start
  t2 = Liquid::Template.parse(template_str)
  prof2.profile(t2, iterations)
  LiquidProf::Profiler.stop

  prof3 = LiquidProf::Profiler.profile(iterations) do
    t3 = Liquid::Template.new
    t3.parse(template_str)
    t3.render
  end

  prof4 = LiquidProf::Profiler.profile(iterations) do
    t4 = Liquid::Template.parse(template_str)
    t4.render
  end

  profs = [ prof1, prof2, prof3, prof4 ]
  0.upto(profs.length-2) do |i|
    (i+1).upto(profs.length-1) do |j|
      assert profs[i] != profs[j]
      assert_stats_equal(profs[i], profs[j])
    end
  end

  return prof1, t1
end
