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
      Profiler.dfs(template.root) do |node, pos|
        next unless pos == :pre
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

      line = 0
      res = ""
      Profiler.dfs(template.root) do |node, pos|
        next if node.class == Liquid::Document
        if pos == :pre
          if node.class == String
            res << node
            line += node.scan(/\r?\n/).length
          elsif node.respond_to?(:raw_markup)
            res << node.raw_markup
          else
            res << node.to_s
          end
        else
          if node.respond_to?(:raw_markup_end)
            res << node.raw_markup_end
            next
          end
        end
      end
      res = res.split(/\r?\n/)
      digits = res.length.to_s.length
      print [*1..res.length].map{ |i| i.to_s.rjust(digits) }.zip(res).map{ |line| line.join(" | ") }.join("\n")
    end
  end

  class Profiler
    attr_accessor :stats

    def initialize(template, tags=Profiler.all_tags()+[Liquid::Variable])
      @stats = {}
      @template = template
      stats_init(template.root)
      add_profiling(tags)
      add_raw_markup(tags)
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

    def add_raw_markup(tags)
      tags = tags - [Liquid::Variable, Liquid::Document]

      Profiler.unhook(:create_variable, Liquid::Block)
      Profiler.hook(:create_variable, Liquid::Block) do |node, method, args|
        var = method.(*args)
        var.instance_variable_set :@raw_markup, args.first
        var.class.class_eval { attr_reader :raw_markup }
        var
      end

      Profiler.unhook(:initialize, Liquid::Tag)
      Profiler.hook(:initialize, Liquid::Tag) do |node, method, args|
        method.(*args)
        node.instance_variable_set :@raw_markup, "{% #{args[0].strip} #{args[1].strip} %}"
        node.class.class_eval { attr_reader :raw_markup }
      end

      Profiler.unhook(:end_tag, Liquid::Block)
      Profiler.hook(:end_tag, Liquid::Block) do |node, method, args|
        node.instance_variable_set :@raw_markup_end, "{% #{node.block_delimiter} %}"
        node.class.class_eval { attr_reader :raw_markup_end }
        method.(*args)
      end
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
      def profile(template, *args)
        Profiler.new(template).profile(*args)
      end

      def all_tags
        ObjectSpace.each_object(Class).select { |klass| klass <= Liquid::Tag }
      end

      def dfs(root, &block)
        block.yield(root, :pre)
        if root.respond_to?(:nodelist) && root.nodelist
          root.nodelist.each do |child|
            dfs(child, &block)
          end
        end
        block.yield(root, :post)
      end

      def hook(method_name, tags, &block)
        [tags].flatten.each do |tag|
          tag.class_exec(block) do |block|
            define_method "#{method_name}_hooked" do |*args|
              block.yield(self, method("#{method_name}_unhooked"), args)
            end

            alias_method "#{method_name}_unhooked", method_name
            alias_method method_name, "#{method_name}_hooked"
          end
        end
      end

      def unhook(method_name, tags)
        [tags].flatten.each do |tag|
          tag.class_eval do
            if method_defined?("#{method_name}_hooked")
              alias_method method_name, "#{method_name}_unhooked"
              remove_method "#{method_name}_hooked"
              remove_method "#{method_name}_unhooked"
            end
          end
        end
      end
    end
  end
end

template = Liquid::Template.new
prof = LiquidProf::Profiler.new(template)

template.parse(STDIN.read)

prof.profile(3)
LiquidProf::AsciiReporter.new(prof).report(template)
prof.stats
