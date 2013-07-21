module LiquidProf
  class AsciiReporter < Reporter
    def format_node_stats(stats)
      [
        "%dx" % stats[:calls][:avg],
        "%.2fms" % (1000.0 * stats[:times][:avg]),
        format_bytes(stats[:lengths][:avg])
      ].join(", ")
    end

    def self.report(prof, template)
      AsciiReporter.new(prof, template).report()
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
end
