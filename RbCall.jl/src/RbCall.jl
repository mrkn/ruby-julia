__precompile__()

module RbCall

export _refcnt, _incref, _decref, gc_guard_references

#########################################################################

if sizeof(Clong) == sizeof(Ptr{Cvoid})
  const VALUE = Culong
  const SVALUE = Clong
  const ID = Culong
elseif sizeof(Clonglong) == sizeof(Ptr{Cvoid})
  const VALUE = Culonglong
  const SVALUE = Clonglong
  const ID = Culonglong
else
  error("ruby requires sizeof(Ptr{Cvoid}) == sizeof(Clong) or sizeof(Clonglong) to be compiled.")
end

mutable struct RubyObject
  o::VALUE
  function RubyObject(o::VALUE)
    ro = new(o)
    gc_guard_register(ro)
    finalizer(gc_guard_unregister, ro)
    return ro
  end
end

#########################################################################

const RUBY_FIXNUM_MAX = typemax(Clong) >> 1
const RUBY_FIXNUM_MIN = typemin(Clong) >> 1

RB_FIXNUM_P(v::VALUE) = (x & RUBY_FIXNUM_FLAG) != 0
RB_POSFIXABLE(x::Integer) = x < RUBY_FIXNUM_MAX+1
RB_NEGFIXABLE(x::Integer) = x >= RUBY_FIXNUM_MIN
RB_FIXABLE(x::Integer) = RB_POSFIXABLE(x) && RB_NEGFIXABLE(x)

RUBY_Qfalse = 0x00
RUBY_Qtrue  = 0x14
RUBY_Qnil   = 0x08
RUBY_Qundef = 0x34

RUBY_IMMEDIATE_MAXK = 0x07
RUBY_FIXNUM_FLAG    = 0x01
RUBY_FLONUM_MASK    = 0x03
RUBY_FLONUM_FLAG    = 0x02
RUBY_SYMBOL_FLAG    = 0x0c

RUBY_SPECIAL_SHIFT  = 8

#########################################################################

include("callback.jl")
include("gc.jl")

end # module RbCall
