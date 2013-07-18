require "liquid"
require "benchmark"

module LLP
  class Profiler
    attr_accessor :hooks, :stats

    def initialize
      @hooks = { render: {}, parse: {} }
      @stats = {}
    end

    def all_tags
      ObjectSpace.each_object(Class).select { |klass| klass <= Liquid::Tag }
    end

    def hook(method_name, tags=all_tags(), &block)
      tags.each do |tag|
        @hooks[method_name][tag] = block

        tag.class_exec(block) do |block|
          define_method "#{method_name}_with_profiling" do |*args|
            block.yield(self, args, method("#{method_name}_without_profiling"))
          end

          alias_method "#{method_name}_without_profiling", method_name
          alias_method method_name, "#{method_name}_with_profiling"
        end
      end
    end

    def unhook(tags=all_tags())
      [:render, :parse].each do |method_name|
        tags.each do |tag|
          @hooks[method_name].delete(tag)
          tag.class_eval do
            alias_method method_name, "#{method_name}_without_profiling"
          end
        end
      end
    end

    def stats_init(node)
      stats = @stats[node.__id__] ||= { times: [], calls: [], output_lengths: [] }
      stats[:calls] << 0
      stats[:times] << []
      stats[:output_lengths] << []
    end

    def stats_inc(node, time, length)
      @stats[node.__id__][:calls][-1] += 1
      @stats[node.__id__][:times][-1] << time
      @stats[node.__id__][:output_lengths][-1] << length
    end

    def add_profiling(tags=all_tags())
      hook(:parse, tags) do |node, args, orig|
        stats_init(node)
        orig.(*args)
      end

      hook(:render, tags) do |node, args, orig|
        output = nil
        time = Benchmark.realtime do
          output = orig.(*args)
        end
        stats_inc(node, time, output.length)
        output
      end
    end
  end
end

prof = LLP::Profiler.new
prof.add_profiling()

ast = Liquid::Template.parse(STDIN.read)
puts ast.render()

p prof.stats
