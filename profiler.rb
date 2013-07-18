require "liquid"
require "benchmark"
require "pp"

module LiquidProf
  class Reporter
    attr_reader :prof

    def initialize(prof)
      @prof = prof
    end

    def summarize_stats(template)
      Profiler.dfs(template.root) do |node|
        next unless prof.stats.key?(node.__id__)
        node_stats_summary(prof.stats[node.__id__])
      end
      self
    end

    private

    def node_stats_summary(stats)
      [:calls, :times, :lengths].each do |field|
        raw = stats[field][:raw]
        stats[field][:avg] = mu = avg(raw)
        stats[field][:max] = raw.max || 0
        stats[field][:min] = raw.min || 0
        stats[field][:dev] = Math.sqrt(raw.inject(0){ |s,i| s + (i - mu)**2 } / (raw.length-1).to_f)
      end
    end

    def avg(array)
      array.length > 0 ? (array.inject(0){ |s,i| s + i }.to_f / array.length.to_f) : 0.0
    end
  end

  class AsciiReporter < Reporter
    def report(template)
      summarize_stats(template)
    end
  end

  class Profiler
    attr_accessor :stats

    def initialize(template, tags=Profiler.all_tags()+[Liquid::Variable])
      @stats = {}
      @template = template
      stats_init(template.root)
      add_profiling(tags)
    end

    def add_profiling(tags)
      Profiler.unhook(:render, tags)
      Profiler.hook(:render, tags) do |node, method, args|
        output = nil
        time = Benchmark.realtime do
          output = method.(*args)
        end
        stats_inc(node, time, output.to_s.length)
        output
      end
    end

    def stats_init(root)
      Profiler.dfs(root) do |node|
        unless node.class == String
          stats_init_node(node)
        end
      end
    end

    def profile(iterations, *args)
      iterations.times do
        stats_init(@template.root)
        @template.render(*args)
      end
      stats
    end

    private

    def stats_init_node(node)
      @stats[node.__id__] ||= {}
      [:calls, :times, :lengths].each do |field|
        @stats[node.__id__][field] ||= {}
        @stats[node.__id__][field][:raw] ||= []
        @stats[node.__id__][field][:raw] << 0
      end
    end

    def stats_inc(node, time, length)
      @stats[node.__id__][:calls][:raw][-1] += 1
      @stats[node.__id__][:times][:raw][-1] += time
      @stats[node.__id__][:lengths][:raw][-1] += length
    end

    class << self
      def profile(*args)
        Profiler.new.profile(*args)
      end

      def all_tags
        ObjectSpace.each_object(Class).select { |klass| klass <= Liquid::Tag }
      end

      def dfs(root, &block)
        block.yield(root)
        if root.respond_to?(:nodelist)
          root.nodelist.each do |child|
            dfs(child, &block)
          end
        end
      end

      def hook(method_name, tags, &block)
        tags.each do |tag|
          tag.class_exec(block) do |block|
            define_method "#{method_name}_with_profiling" do |*args|
              block.yield(self, method("#{method_name}_without_profiling"), args)
            end

            alias_method "#{method_name}_without_profiling", method_name
            alias_method method_name, "#{method_name}_with_profiling"
          end
        end
      end

      def unhook(method_name, tags)
        tags.each do |tag|
          tag.class_eval do
            if method_defined?("#{method_name}_with_profiling")
              alias_method method_name, "#{method_name}_without_profiling"
              remove_method "#{method_name}_with_profiling"
              remove_method "#{method_name}_without_profiling"
            end
          end
        end
      end
    end
  end
end

template = Liquid::Template.parse(STDIN.read)
p template.render()

prof = LiquidProf::Profiler.new(template)
prof.profile(3)
LiquidProf::AsciiReporter.new(prof).report(template)
pp prof.stats
