module RbCall

using VersionParsing

export _refcnt, _incref, _decref, gc_guard_references,
       RubyRange,
       RubyObject, RbPtr, @rbsym, RbNULL

# TODO: Importing Base.convert makes SEGV by convert(::Type{VALUE}, i::Int64)
# import Base: convert
import Base: convert, unsafe_convert

include("prepare.jl")

#########################################################################
# basic types

@static if sizeof(Clong) == sizeof(Ptr{Cvoid})
  const VALUE = Culong
  const SIGNED_VALUE = Clong
  const ID = Culong
  const Cintptr_t = Clong
  const Cuintptr_t = Culong
elseif sizeof(Clonglong) == sizeof(Ptr{Cvoid})
  const VALUE = Culonglong
  const SIGNED_VALUE = Clonglong
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
const RbPtr_NULL = RbPtr(C_NULL)

VALUE(rp::RbPtr) = unsafe_load(Ptr{VALUE}(pointer_from_objref(Ref(rp))))

#########################################################################
# Wrapper type of Ruby object

mutable struct RubyObject
  o::RbPtr
  function RubyObject(o::RbPtr)
    ro = new(o)
    # TODO: GC guard
    return ro
  end
end

RbPtr(ro::RubyObject) = getfield(ro, :o)

"""
    ≛(x, y)

`RbPtr` based comparison of `x` and `y`, which can be of type `RubyObject` or `RbPtr`.
"""
≛(o1::Union{RubyObject,RbPtr}, o2::Union{RubyObject,RbPtr}) = RbPtr(o1) == RbPtr(o2)

"""
    RbNULL()
"""
RbNULL() = RubyObject(RbPtr_NULL)

"""
    isrbnull
"""
isrbnull(ro::RubyObject) = o ≛ RbPtr_NULL

function Base.copy!(dest::RubyObject, src::RubyObject)
  setfield!(dest, :o, RbPtr(src))
  return dest
end

# conversion to pass RubyObject as ccall arguments:
unsafe_convert(::Type{RbPtr}, ro::RubyObject) = RbPtr(ro)

# use constructor for generic conversions to RubyObject
convert(::Type{RubyObject}, o) = RubyObject(o)
convert(::Type{RubyObject}, ro::RubyObject) = ro
RubyObject(ro::RubyObject) = ro

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

const RUBY_T_NONE     = 0x00  # Non-object (swept etc.)
const RUBY_T_OBJECT   = 0x01  # @see struct ::RObject
const RUBY_T_CLASS    = 0x02  # @see struct ::RClass and ::rb_cClass
const RUBY_T_MODULE   = 0x03  # @see struct ::RClass and ::rb_cModule
const RUBY_T_FLOAT    = 0x04  # @see struct ::RFloat
const RUBY_T_STRING   = 0x05  # @see struct ::RString
const RUBY_T_REGEXP   = 0x06  # @see struct ::RRegexp
const RUBY_T_ARRAY    = 0x07  # @see struct ::RArray
const RUBY_T_HASH     = 0x08  # @see struct ::RHash
const RUBY_T_STRUCT   = 0x09  # @see struct ::RStruct
const RUBY_T_BIGNUM   = 0x0a  # @see struct ::RBignum
const RUBY_T_FILE     = 0x0b  # @see struct ::RFile
const RUBY_T_DATA     = 0x0c  # @see struct ::RTypedData
const RUBY_T_MATCH    = 0x0d  # @see struct ::RMatch
const RUBY_T_COMPLEX  = 0x0e  # @see struct ::RComplex
const RUBY_T_RATIONAL = 0x0f  # @see struct ::RRational
const RUBY_T_NIL      = 0x11  # @see ::RUBY_Qnil
const RUBY_T_TRUE     = 0x12  # @see ::RUBY_Qfalse
const RUBY_T_FALSE    = 0x13  # @see ::RUBY_Qtrue
const RUBY_T_SYMBOL   = 0x14  # @see struct ::RSymbol
const RUBY_T_FIXNUM   = 0x15  # Integers formerly known as Fixnums.
const RUBY_T_UNDEF    = 0x16  # @see ::RUBY_Qundef
const RUBY_T_IMEMO    = 0x1a  # @see struct ::RIMemo
const RUBY_T_NODE     = 0x1b  # @see struct ::RNode
const RUBY_T_ICLASS   = 0x1c  # Hidden classes known as IClasses.
const RUBY_T_ZOMBIE   = 0x1d  # @see struct ::RZombie
const RUBY_T_MOVED    = 0x1e  # @see struct ::RMoved
const RUBY_T_MASK     = 0x1f  # Bitmask of ::ruby_value_type.

function RUBY_OBJECT_FLAG(ro::Union{RubyObject,RbPtr})
  o = Base.unsafe_load(RbPtr(ro))
  o.basic.flags
end

RB_BUILTIN_TYPE(ro::Union{RubyObject,RbPtr}) = RUBY_OBJECT_FLAG(ro) & RUBY_T_MASK

function RB_INTEGER_TYPE_P(ro::Union{RubyObject,RbPtr})
  if RB_FIXNUM_P(ro)
    true
  elseif RB_SPECIAL_CONST_P(ro)
    false
  else
    RB_BUILTIN_TYPE(ro) == RUBY_T_BIGNUM
  end
end

function RB_FLOAT_TYPE_P(ro::Union{RubyObject,RbPtr})
  if RB_FLONUM_P(ro)
    true
  elseif RB_SPECIAL_CONST_P(ro)
    false
  else
    RB_BUILTIN_TYPE(ro) == RUBY_T_FLOAT
  end
end

function RB_TYPE_P(ro::Union{RubyObject,RbPtr}, t::Integer)
  rp = RbPtr(ro)
  if t == RUBY_T_TRUE
    rp == RbPtr_Qtrue
  elseif t == RUBY_T_FALSE
    rp == RbPtr_Qfalse
  elseif t == RUBY_T_NIL
    rp == RbPtr_Qnil
  elseif t == RUBY_T_FIXNUM
    RB_FIXNUM_P(rp)
  elseif t == RUBY_T_SYMBOL
    RB_SYMBOL_P(rp)
  elseif t == RUBY_T_FLOAT
    RB_FLOAT_TYPE_P(rp)
  elseif RB_SPECIAL_CONST_P(rp)
    false
  else
    t == RB_BUILTIN_TYPE(rp)
  end
end

@static if RUBY_USE_FLONUM
  const RUBY_Qfalse = VALUE(0x00)
  const RUBY_Qtrue  = VALUE(0x14)
  const RUBY_Qnil   = VALUE(0x08)
  const RUBY_Qundef = VALUE(0x34)
  const RUBY_IMMEDIATE_MASK = VALUE(0x07)
  const RUBY_FIXNUM_FLAG    = VALUE(0x01)
  const RUBY_FLONUM_MASK    = VALUE(0x03)
  const RUBY_FLONUM_FLAG    = VALUE(0x02)
  const RUBY_SYMBOL_FLAG    = VALUE(0x0c)
else
  const RUBY_Qfalse = VALUE(0)
  const RUBY_Qtrue  = VALUE(2)
  const RUBY_Qnil   = VALUE(4)
  const RUBY_Qundef = VALUE(6)
  const RUBY_IMMEDIATE_MASK = VALUE(0x03)
  const RUBY_FIXNUM_FLAG    = VALUE(0x01)
  const RUBY_FLONUM_MASK    = VALUE(0x00)
  const RUBY_FLONUM_FLAG    = VALUE(0x02)
  const RUBY_SYMBOL_FLAG    = VALUE(0x0e)
end
const RUBY_SPECIAL_SHIFT  = VALUE(8)

const RbPtr_Qfalse = RbPtr(RUBY_Qfalse)
const RbPtr_Qtrue = RbPtr(RUBY_Qtrue)
const RbPtr_Qnil = RbPtr(RUBY_Qnil)
const RbPtr_Qundef = RbPtr(RUBY_Qundef)

const RBIMPL_VALUE_FULL = typemax(VALUE)

#########################################################################
# basic utilities

RB_TEST(ro::Union{RubyObject,RbPtr}) = (VALUE(RbPtr(ro)) & ~RUBY_Qnil) != 0

RB_NIL_P(ro::Union{RubyObject,RbPtr}) = ro ≛ RbPtr_Qnil

RB_FIXNUM_P(val::VALUE) = (val & RUBY_FIXNUM_FLAG) != 0
RB_FIXNUM_P(ro::Union{RubyObject,RbPtr}) = RB_FIXNUM_P(VALUE(RbPtr(ro)))

const RUBY_STATIC_SYMBOL_MASK = ~(RBIMPL_VALUE_FULL << RUBY_SPECIAL_SHIFT)
RB_STATIC_SYM_P(ro::Union{RubyObject,RbPtr}) = (VALUE(RbPtr(ro)) & RUBY_STATIC_SYMBOL_MASK) == RUBY_SYMBOL_FLAG

RB_IMMEDIATE_P(ro::Union{RubyObject,RbPtr}) = (VALUE(RbPtr(ro)) & RUBY_IMMEDIATE_MASK) != 0
RB_SPECIAL_CONST_P(ro::Union{RubyObject,RbPtr}) = RB_IMMEDIATE_P(ro) || !RB_TEST(ro)

@static if RUBY_USE_FLONUM
  RB_FLONUM_P(ro::Union{RubyObject,RbPtr}) = (VALUE(RbPtr(ro)) & RUBY_FLONUM_MASK) == RUBY_FLONUM_FLAG
else
  RB_FLONUM_P(ro::Union{RubyObject,RbPtr}) = false
end

RB_POSFIXABLE(x::Integer) = x <= RUBY_FIXNUM_MAX
RB_NEGFIXABLE(x::Integer) = x >= RUBY_FIXNUM_MIN
RB_FIXABLE(x::Integer) = RB_POSFIXABLE(x) && RB_NEGFIXABLE(x)

RB_INT2FIX(i::Integer) = RbPtr((VALUE(i) << 1) | RUBY_FIXNUM_FLAG)
RB_LONG2FIX(i::Clong) = RbPtr(RB_INT2FIX(i))

RbPtr(val::VALUE) = GC.@preserve Base.unsafe_load(Ptr{RbPtr}(pointer([val])))

function RB_LONG2NUM(i::Clong)
  if RB_FIXABLE(i)
    return RB_LONG2FIX(i)
  else
    return ccall(:rb_int2big, RbPtr, (Cintptr_t,), Cintptr_t(i))
  end
end

function RB_ULONG2NUM(i::Culong)
  if RB_POSFIXABLE(i)
    return RB_LONG2FIX(Clong(i))
  else
    return ccall(:rb_uint2big, RbPtr, (Cuintptr_t,), Cuintptr_t(i))
  end
end

function RB_FIX2LONG(ro::Union{RubyObject,RbPtr})
  x = VALUE(RbPtr(ro))
  @assert RB_FIXNUM_P(x)
  y = SIGNED_VALUE(x)
  z = y >> 1
  w = Clong(z)
  @assert RB_FIXABLE(w)
  w
end

RB_NUM2LONG(ro::RubyObject) = RB_FIXNUM_P(ro) ? RB_FIX2LONG(ro) : ccall((@rbsym :rb_num2long), Clong, (RbPtr,), ro)

RB_LL2NUM(i::Clonglong) = ccall(:rb_ll2inum, RbPtr, (Clonglong,), i)
RB_ULL2NUM(i::Culonglong) = ccall(:rb_ull2inum, RbPtr, (Culonglong,), i)

DBL2NUM(d::Cdouble) = ccall(:rb_float_new, RbPtr, (Cdouble,), d)

HAVE_RB_DBL_COMPLEX_NEW = hassym(libruby_handle, :rb_dbl_complex_new)

#########################################################################
# libruby

include("libruby.jl")

#########################################################################
# error

include("error.jl")

#########################################################################
# gc

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

#########################################################################
# init

include("init.jl")

end # module RbCall
