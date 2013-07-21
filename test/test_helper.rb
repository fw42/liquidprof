require 'bundler/setup'
require 'minitest/autorun'
require 'minitest/unit'
require 'minitest/pride'

$LOAD_PATH.unshift File.expand_path('../lib', File.dirname(__FILE__))
require "liquidprof"
