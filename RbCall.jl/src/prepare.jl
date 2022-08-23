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
  script = joinpath(dirname(@__FILE__), "..", "ruby", "find_libruby.rb")
  cmd = `ruby $script`
  println(cmd)
  error("Dynamically loading of libruby.so is not supported yet")
else
  @static if Sys.iswindows()
    # TODO support windows
  else
    libruby_handle = proc_handle
    # Now determine the name of the ruby library that these symbols are from
    some_address_in_libruby = Libdl.dlsym(libruby_handle, :rb_define_class)
    some_address_in_main_exe = Libdl.dlsym_e(proc_handle, Sys.isapple() ? :_mh_execute_header : :main)
    if some_address_in_main_exe == nothing
      # NOTE: we cannot get main symbol from ruby executable in travis-ci
      some_address_in_main_exe = Libdl.dlsym_e(proc_handle, :_start)
    end
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

if libruby == nothing
  macro rbsym(sym)
    esc(sym)
  end

  macro rbglobal(sym)
    :(cglobal($(esc(sym))))
  end

  macro rbglobalobj(sym)
    :(cglobal($(esc(sym)), VALUE))
  end
else
  macro rbsym(sym)
    :(($(esc(sym)), libruby))
  end

  macro rbglobal(sym)
    :(cglobal(($(esc(sym)), libruby)))
  end

  macro rbglobalobj(sym)
    :(cglobal(($(esc(sym)), libruby), VALUE))
  end
end
