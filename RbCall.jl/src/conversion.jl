# Conversions between Julia and Ruby types

#########################################################################
# Conversions of simple types (numbers and nothing)

# conversions from Julia types to RubyObject:

RubyObject(::Nothing) = RubyNothing[]

RubyObject(b::Bool) = RubyObject(RbPtr(b ? RUBY_Qtrue : RUBY_Qfalse))

RubyObject(i::Int8) = RubyObject(RB_INT2FIX(Cint(i)))
RubyObject(i::UInt8) = RubyObject(RB_INT2FIX(Cint(i)))
RubyObject(i::Int16) = RubyObject(RB_INT2FIX(Cint(i)))
RubyObject(i::UInt16) = RubyObject(RB_INT2FIX(Cint(i)))
RubyObject(i::Int32) = RubyObject(RB_LONG2NUM(Clong(i)))
RubyObject(i::UInt32) = RubyObject(RB_ULONG2NUM(Culong(i)))

@static if sizeof(Clong) == sizeof(Int64)
  RubyObject(i::Int64)  = RubyObject(RB_LONG2NUM(Clong(i)))
  RubyObject(i::UInt64) = RubyObject(RB_ULONG2NUM(Culong(i)))
else
  RubyObject(i::Int64)  = RubyObject(RB_LLLG2NUM(Clonglong(i)))
  RubyObject(i::UInt64) = RubyObject(RB_ULLLG2NUM(Culonglong(i)))
end

@static if sizeof(Clonglong) == sizeof(Int128)
  RubyObject(i::Int128)  = RubyObject(RB_LL2NUM(Clonglong(i)))
  RubyObject(i::UInt128) = RubyObject(RB_ULL2NUM(Culonglong(i)))
end

function RubyObject(i::Integer)
  # TODO convert to Bignum
  return RUBY_Qnil
end

RubyObject(d::Union{Float64,Float32}) = DBL2NUM(Cdouble(d))

if HAVE_RB_DBL_COMPLEX_NEW
  function RubyObject(c::Union{ComplexF64,ComplexF32})
    c64 = ComplexF64(c)
    return ccall(:rb_dbl_complex_new, RbPtr, (Cdouble, Cdouble), real(c64), imag(c64))
  end
else
  function RubyObject(c::Union{ComplexF64,ComplexF32})
    c64 = ComplexF64(c)
    return ccall(:rb_complex_new, RbPtr, (RbPtr, RbPtr),
                 convert(RbPtr, real(c64)), convert(RbPtr, imag(c64)))
  end
end

function RubyObject(s::AbstractString)
  sb = String(s)
  return ccall(:rb_utf8_str_new, RbPtr, (Cstring, Clong), sb, sizeof(sb))
end

function RubyObject(sym::Symbol)
  b = Vector{UInt8}(string(sym))
  utf8 = ccall(:rb_utf8_encoding, Ptr{Cvoid}, ())
  id = ccall(:rb_intern3, ID, (Ptr{Cchar}, Clong, Ptr{Cvoid}), b, length(b), utf8)
  return ccall(:rb_id2sym, RbPtr, (ID,), id)
end

function RubyObject(vec::Vector{T}) where {T<:Any}
  n = length(vec)
  ary = ccall(:rb_ary_new_capa, RbPtr, (Clong,), n)
  @inbounds for i in 1:n
    obj = RubyObject(vec[i])
    ccall(:rb_ary_push, RbPtr, (RbPtr, RbPtr), ary, obj)
  end
  return ary
end

RubyObject(x::Any) = jlwrap_new(x)

function convert_to_ruby(value::Any)
  return RubyObject(value)
end
