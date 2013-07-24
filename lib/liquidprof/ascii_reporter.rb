module LiquidProf
  class AsciiReporter < Reporter
    def format_node_stats(stats, skip_times=false)
      [
        skip_times ? nil : ("%dx" % stats[:calls][:avg]),
        "%.2fms" % (1000.0 * stats[:times][:avg]),
        format_bytes(stats[:lengths][:avg])
      ].compact.join(", ")
    end

    def self.report(prof)
      AsciiReporter.new(prof).report()
    end

    def report
      output = ""
      @prof.templates.each do |template|
        output << report_template(template)
        output << "\n"
        output << "\n" if @prof.templates.length > 1
      end
      output
    end

    def report_template(template)
      summarize_stats(template)
      sidenotes = Hash.new{ Array.new }
      res = render_source(template) do |node, line|
        sidenotes[line] += [ @prof.stats[node] ]
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

      output << [ "", format_node_stats(@prof.stats[template.root], true), "" ]
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

      table = ""
      table << [ " " * (max_width[0]+2), "-" * (max_width[1]+4), "" ].join("+") + "\n"
      table << lines[0..-2].map{ |line| line.join("  |  ") }.join("\n") + "\n"
      table << [ " " * (max_width[0]+2), "-" * (max_width[1]+4), "" ].join("+") + "\n"
      table << lines.last.join("     ").rjust(max_width[1])
      table
    end
  end
end
