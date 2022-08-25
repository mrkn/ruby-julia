# Conversions between Julia and Ruby types

#########################################################################
# Conversions of simple types (numbers and nothing)

# conversions from Julia types to RubyObject:

RubyObject(::Nothing) = RubyObject(RbPtr_Qnil)

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

# conversions to Julia types from RubyObject

@static if sizeof(Clong) == sizeof(Int64)
  convert(::Type{T}, ro::RubyObject) where {T<:Union{Int64,Int32,Int16,Int8}} = RB_NUM2LONG(ro)
  convert(::Type{T}, ro::RubyObject) where {T<:Union{UInt64,UInt32,UInt16,UInt8}} = RB_NUM2ULONG(ro)
else
  convert(::Type{T}, ro::RubyObject) where {T<:Union{Int64,Int32,Int16,Int8}} = RB_NUM2LL(ro)
  convert(::Type{T}, ro::RubyObject) where {T<:Union{UInt64,UInt32,UInt16,UInt8}} = RB_NUM2ULL(ro)
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

RubyObject(vec::Vector{T}) where {T<:Float64} = jlwrap_new(vec)

function RubyObject(vec::Vector{T}) where {T<:Any}
  n = length(vec)
  ary = ccall(:rb_ary_new_capa, RbPtr, (Clong,), n)
  @inbounds for i in 1:n
    obj = RubyObject(vec[i])
    ccall(:rb_ary_push, RbPtr, (RbPtr, RbPtr), ary, obj)
  end
  return RubyObject(ary)
end

RubyObject(x::Any) = jlwrap_new(x)

function convert_to_ruby(value::Any)
  return RubyObject(value)
end

const TypeTuple = Union{Type,NTuple{N, Type}} where {N}

abstract type RbAny end

function rbint_query(ro::RubyObject)
  if !RB_INTEGER_TYPE_P(ro)
    Union{}
  elseif RB_FIXNUM_P(ro)
    Int
  else
    leading_zeros = Cint(0)
    size = ccall((@rbsym :rb_absint_size), Csize_t, (RbPtr, Ptr{Cint}), ro, Ref(leading_zeros))
    positive_p = Bool(ccall((@rbsym :rb_big_sign), Cint, (RbPtr,), ro))
    if !positive_p && leading_zeros == 0
      size += 1
    end
    if size <= sizeof(Int64)
      positive_p ? UInt64 : Int64
    else
      BigInt
    end
  end
end

rbfloat_query(ro::RubyObject) = RB_FLOAT_TYPE_P(ro) ? Float64 : Union{}

# TODO
rbcomplex_query(ro::RubyObject) = Union{}

function rbstring_query(ro::RubyObject)
  if RB_TYPE_P(ro, RUBY_T_STRING)
    # TODO: taking care of the encoding
    String
  else
    Union{}
  end
end

rbnil_query(ro::RubyObject) = ro ≛ RbPtr_Qnil ? Nothing : Union{}

# TODO: rbarray, rbhash, ...

macro return_not_None(ex)
  quote
    T = $(esc(ex))
    if T != Union{}
      return T
    end
  end
end

const rbtype_queries = Tuple{RubyObject, Type}[]

"""
    rbtype_mapping(rb_class::RubyObject, jl_type::Type)
"""
function rbtype_mapping(rb_class::RubyObject, jl_type::Type)
  for (i, (r, j)) in enumerate(rbtype_queries)
    if r == rb_class
      rbtype_queries[i] = (rb_class, jl_type)
      return rbtype_queries
    end
  end
  push!(rbtype_queries, (rb_class, jl_type))
end

"""
    rbtype_query(ro::RubyObject, default=RubyObject)
"""
function rbtype_query(ro::RubyObject, default::TypeTuple=RubyObject)
  for (rb_class, jl_type) in rbtype_queries
    if rb_obj_is_kind_of(ro, rb_class)
      return jl_type
    end
  end
  @return_not_None rbint_query(ro)
  @return_not_None rbfloat_query(ro)
  @return_not_None rbcomplex_query(ro)
  @return_not_None rbstring_query(ro)
  # TODO: @return_not_None rbarray_query(ro)
  # TODO: @return_not_None rbhash_query(ro)
  # TODO: @return_not_None rbtime_query(ro)
   @return_not_None rbnil_query(ro)
   return default
end

function convert(::Type{RbAny}, ro::RubyObject)
  if RB_NIL_P(ro)
    return ro
  end
  try
    T = rbtype_query(ro)
    if T == RubyObject && is_jlwrap(ro)
      return unsafe_jlwrap_to_objref(ro)
    end
    convert(T, ro)
  catch
    rberr_clear()  # just in case
    rethrow()
    # ro
  end
end
