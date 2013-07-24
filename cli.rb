require "liquidprof"

prof = LiquidProf::Profiler.profile(1) do
  input = STDIN.read
  Liquid::Template.parse(input).render
end

puts LiquidProf::AsciiReporter.report(prof)
