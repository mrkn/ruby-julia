module RbCall

export _refcnt, _incref, _decref, gc_guard_references,
       RubyRange

# TODO: Importing Base.convert makes SEGV by convert(::Type{VALUE}, i::Int64)
# import Base: convert

include("prepare.jl")

#########################################################################
# basic types

@static if sizeof(Clong) == sizeof(Ptr{Cvoid})
  const VALUE = Culong
  const SVALUE = Clong
  const ID = Culong
  const Cintptr_t = Clong
  const Cuintptr_t = Culong
elseif sizeof(Clonglong) == sizeof(Ptr{Cvoid})
  const VALUE = Culonglong
  const SVALUE = Clonglong
  const ID = Culonglong
  const Cintptr_t = Clonglong
  const Cuintptr_t = Culonglong
else
  error("ruby requires sizeof(Ptr{Cvoid}) == sizeof(Clong) or sizeof(Clonglong) to be compiled.")
end

struct RBasic_struct
  flags::VALUE
  klass::VALUE
end

struct RVALUE_struct
  basic::RBasic_struct
  v1::VALUE
  v2::VALUE
  v3::VALUE
end

const RbPtr = Ptr{RVALUE_struct}

#########################################################################
# basic constants

const RUBY_FIXNUM_MAX = typemax(Clong) >> 1
const RUBY_FIXNUM_MIN = typemin(Clong) >> 1

@static if sizeof(VALUE) >= sizeof(Cdouble)
  const RUBY_USE_FLONUM = true
else
  const RUBY_USE_FLONUM = false
  error("currently RbCall.jl only supports Ruby with flonum.")
end

@static if RUBY_USE_FLONUM
  const RUBY_Qfalse = 0x00
  const RUBY_Qtrue  = 0x14
  const RUBY_Qnil   = 0x08
  const RUBY_Qundef = 0x34
  const RUBY_IMMEDIATE_MASK = 0x07
  const RUBY_FIXNUM_FLAG    = 0x01
  const RUBY_FLONUM_MASK    = 0x03
  const RUBY_FLONUM_FLAG    = 0x02
  const RUBY_SYMBOL_FLAG    = 0x0c
else
  const RUBY_Qfalse = 0
  const RUBY_Qtrue  = 2
  const RUBY_Qnil   = 4
  const RUBY_Qundef = 6
  const RUBY_IMMEDIATE_MASK = 0x03
  const RUBY_FIXNUM_FLAG    = 0x01
  const RUBY_FLONUM_MASK    = 0x00
  const RUBY_FLONUM_FLAG    = 0x02
  const RUBY_SYMBOL_FLAG    = 0x0e
end
const RUBY_SPECIAL_SHIFT  = 8

#########################################################################
# basic utilities

RB_FIXNUM_P(v::VALUE) = (x & RUBY_FIXNUM_FLAG) != 0
RB_POSFIXABLE(x::Integer) = x <= RUBY_FIXNUM_MAX
RB_NEGFIXABLE(x::Integer) = x >= RUBY_FIXNUM_MIN
RB_FIXABLE(x::Integer) = RB_POSFIXABLE(x) && RB_NEGFIXABLE(x)

RB_INT2FIX(i::Integer) = (VALUE(i) << 1) | RUBY_FIXNUM_FLAG
RB_LONG2FIX(i::Clong) = RB_INT2FIX(i)

function RB_LONG2NUM(i::Clong)
  if RB_FIXABLE(i)
    return RB_LONG2FIX(i)
  else
    return ccall(:rb_int2big, VALUE, (Cintptr_t,), Cintptr_t(i))
  end
end

function RB_ULONG2NUM(i::Culong)
  if RB_POSFIXABLE(i)
    return RB_LONG2FIX(Clong(i))
  else
    return ccall(:rb_uint2big, VALUE, (Cuintptr_t,), Cuintptr_t(i))
  end
end

RB_LL2NUM(i::Clonglong) = ccall(:rb_ll2inum, VALUE, (Clonglong,), i)
RB_ULL2NUM(i::Culonglong) = ccall(:rb_ull2inum, VALUE, (Culonglong,), i)

DBL2NUM(d::Cdouble) = ccall(:rb_float_new, VALUE, (Cdouble,), d)

HAVE_RB_DBL_COMPLEX_NEW = hassym(libruby_handle, :rb_dbl_complex_new)

#########################################################################
# libruby

include("libruby.jl")

#########################################################################
# range

include("gc.jl")

#########################################################################
# conversion

include("conversion.jl")

#########################################################################
# range

include("range.jl")

#########################################################################
# wrapper

include("jlwrap.jl")

#########################################################################
# gc

const gc_guard_references = Dict{Any,Clong}()

function _refcnt(value::Any)
  return get(gc_guard_references, value , 0)
end

function _incref(value::Any)
  gc_guard_references[value] = _refcnt(value) + 1
  return value
end

function _decref(value::Any)
  if haskey(gc_guard_references, value)
    new_count = _refcnt(value) - 1
    if new_count == 0
      delete!(gc_guard_references, value)
    else
      gc_guard_references[value] = new_count
    end
  end
end

end # module RbCall
