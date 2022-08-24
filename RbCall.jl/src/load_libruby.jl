const RBCALL_DEBUG = "yes" == get(ENV, "RBCALL_DEBUG", "no")

function rbconfig(ruby::AbstractString, expr::AbstractString)
  chomp(read(`$ruby -rrbconfig -rrbconfig/sizeof -e "puts $expr"`, String))
end

function show_dlopen_error(lib, e)
  if RBCALL_DEBUG
    println(stderr, "dlopen(lib) ===> ", e)
  end
end

#script = joinpath(dirname(@__FILE__), "..", "ruby", "find_libruby.rb")

function find_libruby(ruby::AbstractString; _dlopen = Libdl.dlopen)
  dlopen_flags = Libdl.RTLD_LAZY|Libdl.RTLD_DEEPBIND|Libdl.RTLD_GLOBAL

  libdir = rbconfig(ruby, "RbConfig::CONFIG[\"libdir\"]")
  for libname in ["libruby.so"]
    lib = joinpath(libdir, libname)
    try
      _dlopen(lib, dlopen_flags)
      return lib
    catch e
      show_dlopen_error(lib, e)
    end
  end

  v = rbconfig(ruby, "RUBY_VERSION")
  error("""
        Couldn't find libruby; check your RUBY environment variable.

        The ruby executable we tried was $ruby (= version $v).
        Re-run with
          ENV["RBCALL_DEBUG"] = "yes"
        may provide extra information for why it failed.
        """)
end

const prefsfile = joinpath(first(DEPOT_PATH), "prefs", "RbCall")
mkpath(dirname(prefsfile))

const ruby = try
  let rb = get(ENV, "RUBY", isfile(prefsfile) ? readchomp(prefsfile) : "ruby")
    vers = vparse(rbconfig(rb, "RUBY_VERSION"))
    if vers < v"2.6"
      error("Ruby version $vers < 2.6 is not supported")
    end

    # check word-size consistency between Ruby and Julia
    rbwordsize = parse(UInt64, rbconfig(rb, "RbConfig::SIZEOF[\"ssize_t\"]")) * 8
    if rbwordsize != Sys.WORD_SIZE
      error("$rb is $(rbwordsize)-bit, but Julia is $(Sys.WORD_SIZE)-bit")
    end

    rb
  end
catch e1
  @info ("No installed Ruby was found by the following error: $e1")
  rethrow(e1)
end

const libruby = find_libruby(ruby)
const ruby_programname = rbconfig(ruby, "RbConfig.ruby")

begin
  local ruby_version = vparse(rbconfig(ruby, "RUBY_VERSION"))

  @info "RbCall is using $ruby (Ruby $ruby_version) at $ruby_programname, libruby = $libruby"
end
