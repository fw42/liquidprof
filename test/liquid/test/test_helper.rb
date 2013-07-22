$LOAD_PATH.unshift File.expand_path('../lib', File.dirname(__FILE__))

require "liquidprof"
LiquidProf::Profiler.start

require File.expand_path("liquid_test_helper.rb", File.dirname(__FILE__))
