require "liquidprof"

prof = LiquidProf::Profiler.profile(100) do
  Liquid::Template.parse(STDIN.read).render
end

puts LiquidProf::AsciiReporter.report(prof, prof.templates.first)
