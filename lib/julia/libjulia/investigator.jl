# See https://github.com/JuliaLang/julia/pull/25102
if VERSION < v"0.7.0-DEV.3073"
  bindir = JULIA_HOME
else
  bindir = Sys.BINDIR
end

if VERSION >= v"0.7.0-DEV.3382"
  using Libdl
end

println("VERSION: $(VERSION)")

jl_share = abspath(joinpath(bindir, Base.DATAROOTDIR, "julia"))
println("JL_HOME: $(jl_share)")

libdir = abspath(dirname(Libdl.dlpath("libjulia")))
println("libdir: $(libdir)")
