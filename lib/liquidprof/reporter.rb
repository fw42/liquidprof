module LiquidProf
  class Reporter
    attr_reader :prof

    def initialize(prof, template)
      @prof = prof
      @template = template
    end

    def summarize_stats(template)
      Profiler.dfs(template.root) do |node, pos|
        next unless pos == :pre
        next unless prof.stats.key?(node)
        node_summarize_stats(prof.stats[node])
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

      if exponent == 0
        "#{bytes.to_i}#{units[exponent]}"
      else
        "%.2f%s" % [ bytes, units[exponent] ]
      end
    end

    private

    def node_summarize_stats(stats)
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
end
