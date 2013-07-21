module LiquidProf
  class Profiler
    attr_accessor :stats, :templates

    def stats_init(root)
      if root.class == Liquid::Template
        @templates << root
        return stats_init(root.root)
      end

      Profiler.dfs(root) do |node, pos|
        next unless pos == :pre
        next if node.class == String
        stats_init_node(node)
      end
    end

    def profile(template, iterations=1, *args)
      iterations.times do
        stats_init(template)
        template.render!(*args)
      end
      template
    end

    def remove_raw_markup
      Profiler.unhook(:create_variable, Liquid::Block)
      Profiler.unhook(:initialize, Liquid::Tag)
      Profiler.unhook(:end_tag, Liquid::Block)
    end

    def add_raw_markup
      Profiler.hook(:create_variable, Liquid::Block) do |node, method, args|
        var = method.(*args)
        var.instance_variable_set :@raw_markup, args.first
        var.class.class_eval { attr_reader :raw_markup }
        var
      end

      Profiler.hook(:initialize, Liquid::Tag) do |node, method, args|
        method.(*args)
        node.instance_variable_set :@raw_markup, "{% " + (args[0].strip + " " + args[1].strip).strip + " %}"
        node.class.class_eval { attr_reader :raw_markup }
      end

      Profiler.hook(:end_tag, Liquid::Block) do |node, method, args|
        node.instance_variable_set :@raw_markup_end, "{% #{node.block_delimiter} %}"
        node.class.class_eval { attr_reader :raw_markup_end }
        method.(*args)
      end
    end

    def remove_profiling(tags)
      Profiler.unhook(:render, tags)
    end

    def add_profiling(tags)
      Profiler.hook(:render, tags) do |node, method, args|
        output = nil
        start = Time.now
        output = method.(*args)
        time = Time.now - start
        stats_inc(node, time, output.to_s.length)
        output
      end
    end

    private

    def initialize(tags)
      @stats = {}
      @templates = []
      add_profiling(tags)
      add_raw_markup()
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
      def profiler
        @@profiler
      end

      def start
        @@profiler ||= Profiler.new(Profiler.all_tags() + [Liquid::Variable])
      end

      def stop
        return unless @@profiler
        tags = Profiler.all_tags() + [Liquid::Variable]
        @@profiler.remove_profiling(tags)
        @@profiler.remove_raw_markup()
        prof = @@profiler
        @@profiler = nil
        prof
      end

      def profile(iterations=1, &block)
        prof = Profiler.start

        hook(:parse, Liquid::Template) do |template, method, args|
          method.(*args)
        end

        hook(:render, Liquid::Template) do |template, method, args|
          output = ""
          prof.stats_init(template)
          iterations.times do
            output = method.(*args)
          end
          output
        end

        yield

        unhook(:parse, Liquid::Template)
        unhook(:render, Liquid::Template)
        Profiler.stop
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
            hooked_name = LiquidProf::Profiler.hooked(method_name, tag)
            unhooked_name = LiquidProf::Profiler.unhooked(method_name, tag)

            define_method(hooked_name) do |*args|
              owner = self.class.instance_method(method_name).owner
              if method_name != :render || (self.class == owner && owner == tag)
                block.yield(self, method(unhooked_name), args)
              else
                send(unhooked_name, *args)
              end
            end

            alias_method unhooked_name, method_name
            alias_method method_name, hooked_name
          end
        end
      end

      def unhook(method_name, tags)
        [tags].flatten.each do |tag|
          tag.class_eval do |tag|
            if method_defined?(LiquidProf::Profiler.hooked(method_name, tag))
              alias_method method_name, LiquidProf::Profiler.unhooked(method_name, tag)
              remove_method LiquidProf::Profiler.hooked(method_name, tag)
              remove_method LiquidProf::Profiler.unhooked(method_name, tag)
            end
          end
        end
      end

      def hooked(method_name, tag)
        "#{method_name}_#{tag}_hooked"
      end

      def unhooked(method_name, tag)
        "#{method_name}_#{tag}_unhooked"
      end
    end
  end
end
