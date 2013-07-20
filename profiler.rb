require "liquid"
require "pp"

module LiquidProf
  class Reporter
    attr_reader :prof

    def initialize(prof)
      @prof = prof
      @template = prof.template
    end

    def summarize_stats(template)
      Profiler.dfs(template.root) do |node, pos|
        next unless pos == :pre
        next unless prof.stats.key?(node.__id__)
        node_stats_summary(prof.stats[node.__id__])
      end
      self
    end

    def format_bytes(bytes)
      units = ["B", "K", "M"]

      if bytes.to_i < 1024
        exponent = 0
      else
        exponent = (Math.log(bytes)/Math.log(1024)).to_i
        bytes /= 1024 ** [exponent, units.size].min
      end

      "#{bytes}#{units[exponent]}"
    end

    private

    def node_stats_summary(stats)
      [:calls, :times, :lengths].each do |field|
        raw = stats[field][:raw]
        stats[field][:avg] = mu = avg(raw)
        stats[field][:max] = raw.max || 0
        stats[field][:min] = raw.min || 0
        stats[field][:dev] = raw.length == 1 ? 0.0 : Math.sqrt(raw.inject(0){ |s,i| s + (i - mu)**2 } / (raw.length-1).to_f)
      end
    end

    def avg(array)
      array.length > 0 ? (array.inject(0){ |s,i| s + i }.to_f / array.length.to_f) : 0.0
    end

    def render_source(template)
      res = ""
      line = 0
      Profiler.dfs(template.root) do |node, pos|
        next if node.class == Liquid::Document
        if pos == :pre
          res << if node.class == String
            line += node.scan(/\r?\n/).length
            node
          else
            yield(node, line)
          end
        else
          if node.respond_to?(:raw_markup_end)
            res << node.raw_markup_end
            next
          end
        end
      end
      res.split(/\r?\n/)
    end
  end

  class AsciiReporter < Reporter
    def format_node_stats(stats)
      [ "%dx" % stats[:calls][:avg], "%.2fms" % (100.0 * stats[:times][:avg]), format_bytes(stats[:lengths][:avg]) ].join(", ")
    end

    def self.report(template)
      reporter = AsciiReporter.new(template)
      reporter.report()
    end

    def report
      summarize_stats(@template)
      sidenotes = Hash.new{ Array.new }
      res = render_source(@template) do |node, line|
        sidenotes[line] += [ @prof.stats[node.__id__] ]
        node.raw_markup
      end
      sidenotes = sidenotes.inject(Array.new) do |a,(k,v)|
        a[k] = v.map{ |stats| format_node_stats(stats) }
        a
      end

      output = []
      res.each_with_index do |line, i|
        (sidenotes[i] || [""]).each_with_index do |note, j|
          output << ((j == 0) ? [ (i+1).to_s, note, line] : [ "", note, "" ])
        end
      end

      format_table(output)
    end

    def format_table(lines)
      max_width = []

      lines.each do |line|
        line.each_with_index do |column, i|
          next if i == line.length-1
          max_width[i] = [ max_width[i], column.length ].compact.max
        end
      end

      lines.each do |line|
        line.each_with_index do |column, i|
          next if i == line.length-1
          line[i] = column.rjust(max_width[i])
        end
      end

      lines.map{ |line| line.join("  |  ") }.join("\n")
    end
  end

  class Profiler
    attr_accessor :stats, :template

    def initialize(template, tags=Profiler.all_tags()+[Liquid::Variable])
      @stats = {}
      @template = template
      add_profiling(tags)
      add_raw_markup(tags)
    end

    def stats_init(root)
      Profiler.dfs(root) do |node, pos|
        next unless pos == :pre
        next if node.class == String
        stats_init_node(node)
      end
    end

    def profile(iterations=1, *args)
      iterations.times do
        stats_init(@template.root)
        @template.render!(*args)
      end
      self
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
        node.instance_variable_set :@raw_markup, "{% " + (args[0].strip + " " + args[1].strip).strip + " %}"
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
        start = Time.now
        output = method.(*args)
        time = Time.now - start
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
      return unless @stats[node.__id__]
      @stats[node.__id__][:calls][:raw][-1] += 1
      @stats[node.__id__][:times][:raw][-1] += time
      @stats[node.__id__][:lengths][:raw][-1] += length
    end

    class << self
      def parse(*args)
        template = Liquid::Template.new
        prof = Profiler.new(template)
        template.parse(*args)
        prof
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
          tag.class_exec(block, tag) do |block, tag|
            hooked = "#{method_name}_#{tag}_hooked"
            unhooked = "#{method_name}_#{tag}_unhooked"

            define_method hooked do |*args|
              owner = self.class.instance_method(method_name).owner
              if method_name != :render || (self.class == owner && owner == tag)
                block.yield(self, method(unhooked), args)
              else
                send(unhooked, *args)
              end
            end

            alias_method unhooked, method_name
            alias_method method_name, hooked
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

prof = LiquidProf::Profiler.parse(STDIN.read)
puts LiquidProf::AsciiReporter.report(prof.profile)
prof.stats
