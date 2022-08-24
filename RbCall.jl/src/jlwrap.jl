mutable struct jlwrap_t
  rbobj::RubyObject  # for finalizer
  value::Any
end

function jlwrap_free(ptr::Ptr{jlwrap_t})::Cvoid
  data = Base.unsafe_load(ptr)
  delete!(gcguard, data.rbobj)
  return
end

function jlwrap_size(ptr::Ptr{jlwrap_t})::Csize_t
  data = Base.unsafe_load(ptr)
  return sizeof(jlwrap_t) + sizeof(data.value)
end

const jlwrap_type_name = Base.unsafe_convert(Cstring, "julia.jlwrap")
const jlwrap_data_type = Ref{rb_data_type_t}()
jlwrap_data_type[] = rb_data_type_t(jlwrap_type_name;
                                    dfree=@cfunction(jlwrap_free, Cvoid, (Ptr{jlwrap_t},)),
                                    dsize=@cfunction(jlwrap_size, Csize_t, (Ptr{jlwrap_t},))
                                   )

function is_jlwrap(ro::RubyObject)
  Bool(ccall((@rbsym :rb_typeddata_is_kind_of), Cint, (RbPtr, Ptr{rb_data_type_t}), ro, jlwrap_data_type))
end

function jlwrap_new(x::Any)::RubyObject
  obj = TypedData_Make_Struct(cJuliaWrapper, jlwrap_t, jlwrap_data_type)
  Base.unsafe_store!(Ptr{jlwrap_t}(RTYPEDDATA_DATA(obj)), jlwrap_t(obj, x))
  gcguard[obj] = x
  return obj
end

function unsafe_jlwrap_to_objref(ro::Union{RubyObject,RbPtr})
  GC.@preserve ro begin
    data = Base.unsafe_load(Ptr{jlwrap_t}(RTYPEDDATA_DATA(ro)))
    data.value
  end
end

function julia_args(argc::Cint, argv::Ptr{RbPtr})::Vector{Any}
  args = Any[]
  for i in 1:(argc)
    ptr = Base.unsafe_load(argv, i)
    jl = convert(RbAny, RubyObject(ptr))
    push!(args, jl)
  end
  args
end

function jlwrap_call(argc::Cint, argv::Ptr{RbPtr}, obj::RbPtr)::RbPtr
  # TODO: process arguments
  value = unsafe_jlwrap_to_objref(obj)
  if argc == 0
    res = RubyObject(value())
  else
    args = julia_args(argc, argv)
    rv = value(args...)
    res = RubyObject(rv)
  end
  return res.o
end

function jlwrap_inspect(obj::RbPtr)::RbPtr
  value = unsafe_jlwrap_to_objref(obj)
  str = string("#<Julia::JuliaBridge::JuliaWrapper ", value, ">")
  return RubyObject(str)
end
