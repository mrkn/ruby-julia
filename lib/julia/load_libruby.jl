function find_library(ruby::AbstractString)
  v = rbexpr(ruby, "RUBY_VERSION", "")
  libs = [ dlprefix*"ruby"*v, dlprefix*"ruby" ]
  lib = rbconfig_expand(ruby, "\$(LIBRUBY_SO)")
  lib != nothing && unshift!(libs, splitext(lib)[1])
  libs = unique(libs)

  libpaths = [ rbconfig_expand(ruby, "\$(libdir)") ]
  ruby_path = rbexpr(ruby, "RbConfig.ruby")
  if ruby_path != nothing
    if is_windows()
      push!(libpaths, dirname(ruby_path))
    else
      push!(libpaths, joinpath(dirname(dirname(ruby_path)), "lib"))
    end
  end
  if is_apple()
    # TODO: The framework directory of the system ruby should be added in libpaths
  end

  exec_prefix = rbconfig(ruby, "exec_prefix")
  push!(libpaths, exec_prefix)
  push!(libpaths, joinpath(exec_prefix, "lib"))

  error_strings = Compat.String[]

  # find libruby
  for lib in libs
    for libpath in libpaths
      libpath_lib = joinpath(libpath, lib)
      if isfile(libpath_lib*"."*Libdl.dlext)
        try
          return (Libdl.dlopen(libpath_lib,
                               Libdl.RTLD_LAZY | Libdl.RTLD_DEEPBIND | Libdl.RTLD_GLOBAL),
                  libpath_lib)
        catch e
          push!(error_strings, string("dlopen($libpath_lib) ==> ", e))
        end
      end
    end
  end

  # find libruby from the system library path
  for lib in libs
    lib = splitext(lib)[1]
    try
      return (Libdl.dlopen(lib, Libdl.RTLD_LAZY | Libdl.RTLD_DEEPBIND | Libdl.RTLD_GLOBAL),
              lib)
    catch e
      push!(error_strings, string("dlopen($lib) ==> ", e))
    end
  end
end

const ruby = "ruby"

const (libruby_handle, libruby) = find_library(ruby)
const programname = rbexpr(ruby, "RbConfig.ruby")
const ruby_version = convert(VersionNumber, rbexpr(ruby, "RUBY_VERSION"))
