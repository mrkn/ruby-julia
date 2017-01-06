module Ruby

using Compat

# startup
# =======

hassym(lib, sym) = Libdl.dlsym_e(lib, sym) != C_NULL

function rbexpr(ruby::AbstractString, var::AbstractString)
  val = chomp(readstring(`$ruby -rrbconfig -e "puts $var"`))
  if val == ""
    return nothing
  end
  return val
end

function rbexpr(ruby, var, default)
  val = rbexpr(ruby, var)
  return val == nothing ? default : val
end

function rbconfig(ruby::AbstractString, key::AbstractString)
  return rbexpr(ruby, "RbConfig::CONFIG['$key']")
end

function rbconfig_expand(ruby::AbstractString, make_expr::AbstractString)
  return rbexpr(ruby, "RbConfig.expand('$make_expr')")
end

const dlprefix = is_windows() ? "" : "lib"

immutable Dl_info
    dli_fname::Ptr{UInt8}
    dli_fbase::Ptr{Void}
    dli_sname::Ptr{UInt8}
    dli_saddr::Ptr{Void}
end

proc_handle = unsafe_load(@static is_windows() ?
                          cglobal(:jl_exe_handle, Ptr{Void}) :
                          cglobal(:jl_dl_handle, Ptr{Void}))

symbols_present = false
@static if is_windows()
    EnumProcessModules(hProcess, lphModule, cb, lpcbNeeded) =
        ccall(:K32EnumProcessModules, stdcall, Bool,
              (Ptr{Void}, Ptr{Ptr{Void}}, UInt32, Ptr{UInt32}),
              hProcess, lphModule, cb, lpcbNeeded)

    lpcbNeeded = Ref{UInt32}()
    handles = Vector{Ptr{Void}}(20)
    if EnumProcessModules(proc_handle, handles, sizeof(handles), lpcbNeeded) == 0
        resize!(handles, div(lpcbNeeded[], sizeof(Ptr{Void})))
        EnumProcessModules(proc_handle, handles, sizeof(handles), lpcbNeeded)
    end
    # Try to find ruby if it's in the current process
    for handle in handles
        sym = ccall(:GetProcAddress, stdcall, Ptr{Void},
                    (Ptr{Void}, Ptr{UInt8}), handle, "rb_sysinit")
        sym != C_NULL || continue
        symbols_present = true
        global libruby_handle = handle
        break
    end
else
    symbols_present = hassym(proc_handle, :rb_sysinit)
end

if !symbols_present
    # Ruby not present.  Load libruby here.
    include(joinpath(dirname(@__FILE__), "load_libruby.jl"))
else
    @static if is_windows()
        pathbuf = Vector{UInt16}(1024)
        ret = ccall(:GetModuleFileNameW, stdcall, UInt32,
                    (Ptr{Void}, Ptr{UInt16}, UInt32),
                    libruby_handle, pathbuf, length(pathbuf))
        @assert ret != 0
        libname = String(Base.transcode(UInt8, pathbuf[1:findfirst(pathbuf, 0)-1]))
    else
        libruby_handle = proc_handle
        # Now determine the name of the ruby library that these symbols are from
        some_address_in_libruby = Libdl.dlsym(libruby_handle, :rb_sysinit)
        dlinfo = Ref{Dl_info}()
        ccall(:dladdr, Cint, (Ptr{Void}, Ptr{Dl_info}), some_address_in_libruby, dlinfo)
        libname = unsafe_string(dlinfo[].dli_fname)
    end
    if Libdl.dlopen_e(libname) != C_NULL
        const libruby = libname
    else
        const libruby = nothing
    end
end

if libruby == nothing
    macro rbsym(func)
        :($func)
    end
    macro rbglobal(name)
        :(cglobal($name))
    end
else
    macro rbsym(func)
        :(($func, libruby))
    end
    macro rbglobal(name)
        :(cglobal(($name, libruby)))
    end
end

@static if sizeof(Clong) == sizeof(Ptr{Void})
    typealias VALUE Culong
    typealias ID Culong
    typealias SIGNED_VALUE Clong
else
    @static if sizeof(Clonglong) == sizeof(Ptr{Void})
        typealias VALUE Culonglong
        typealias ID Culonglong
        typealias SIGNED_VALUE Clonglong
    else
        error("shouldn't be reached here")
    end
end

# definitions
# -----------

# special constants - i.e. non-zero and non-fixnum constants

# NOTE: Ruby.jl assumes ruby was built with flonum support.

const Qfalse = VALUE(0x00)          # ...0000 0000
const Qtrue  = VALUE(0x14)          # ...0001 0100
const Qnil   = VALUE(0x08)          # ...0000 1000
const Qundef = VALUE(0x34)          # ...0011 0100

const IMMEDIATE_MASK = VALUE(0x07)
const FIXNUM_FLAG    = VALUE(0x01)  # ...xxxx xxx1
const FLONUM_MASK    = VALUE(0x03)
const FLONUM_FLAG    = VALUE(0x02)  # ...xxxx xx10
const SYMBOL_FLAG    = VALUE(0x0c)  # ...0000 1100

const SPECIAL_SHIFT  = VALUE(8)

const FIXNUM_MAX = typemax(Clong) >> 1
const FIXNUM_MIN = typemin(Clong) >> 1

LONG2FIX(i::Clong) = ((VALUE(i) << 1) | FIXNUM_FLAG)

FIX2LONG(x::VALUE) = Clong(SIGNED_VALUE(x) >> 1)
FIX2ULONG(x::VALUE) = Culong(FIX2LONG(x))
FIXNUM_P(f::SIGNED_VALUE) = (f & FIXNUM_FLAG) != 0
POSFIXABLE(f::Integer) = f < FIXNUM_MAX + 1
NEGFIXABLE(f::Integer) = f >= FIXNUM_MIN
FIXABLE(f::Integer) = POSFIXABLE(f) && NEGFIXABLE(f)

# initialize
# ----------

function __init__()
    already_initialized = 0 != unsafe_load(Ptr{VALUE}(@rbglobal(:rb_cObject)))
    if !already_initialized
        ccall((@rbsym :ruby_init), Void, ())
    end
end

end # module Ruby
