#########################################################################
# prepare

import Libdl

struct Dl_info
    dli_fname::Ptr{UInt8}
    dli_fbase::Ptr{Cvoid}
    dli_sname::Ptr{UInt8}
    dli_saddr::Ptr{Cvoid}
end

hassym(lib, sym) = Libdl.dlsym_e(lib, sym) != C_NULL

proc_handle = unsafe_load(cglobal(:jl_exe_handle, Ptr{Cvoid}))

symbols_present = false
@static if Sys.iswindows()
  error("Windows is not supported yet")
  # TODO support windows
else
  global symbols_present = hassym(proc_handle, :rb_define_class)
end

if !symbols_present
  # Load libruby dynamically
  include("load_libruby.jl")
  libruby_handle = try
    Libdl.dlopen(libruby, Libdl.RTLD_LAZY|Libdl.RTLD_DEEPBIND|Libdl.RTLD_GLOBAL)
  catch err
    if err isa ErrorException
      error(err.msg)
    else
      rethrow(err)
    end
  end
else
  @static if Sys.iswindows()
    # TODO support windows
  else
    libruby_handle = proc_handle
    # Now determine the name of the ruby library that these symbols are from
    some_address_in_libruby = Libdl.dlsym(libruby_handle, :rb_define_class)
    some_address_in_main_exe = Libdl.dlsym_e(proc_handle, Sys.isapple() ? :_mh_execute_header : :_start)
    dlinfo1 = Ref{Dl_info}()
    dlinfo2 = Ref{Dl_info}()
    ccall(:dladdr, Cint, (Ptr{Cvoid}, Ptr{Dl_info}), some_address_in_libruby, dlinfo1)
    ccall(:dladdr, Cint, (Ptr{Cvoid}, Ptr{Dl_info}), some_address_in_main_exe, dlinfo2)
    if dlinfo1[].dli_fbase == dlinfo2[].dli_fbase
      const libruby = nothing
    else
      const libruby = unsafe_string(dlinfo1[].dli_fname)
    end
  end
end

const ruby_version = vparse(unsafe_string(cglobal((:ruby_version, libruby), Cchar)))

if libruby == nothing
  macro rbsym(sym)
    esc(sym)
  end

  macro rbglobal(sym)
    :(cglobal($(esc(sym))))
  end

  macro rbglobalobj(sym)
    :(cglobal($(esc(sym)), RbPtr))
  end
else
  macro rbsym(sym)
    :(($(esc(sym)), libruby))
  end

  macro rbglobal(sym)
    :(cglobal(($(esc(sym)), libruby)))
  end

  macro rbglobal(sym, type)
    :(cglobal(($(esc(sym)), libruby), $(esc(type))))
  end

  macro rbglobalobj(sym)
    :(cglobal(($(esc(sym)), libruby), RbPtr))
  end
end
