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

function jlwrap_new(x::Any)::RubyObject
  obj = TypedData_Make_Struct(cJuliaWrapper, jlwrap_t, jlwrap_data_type)
  Base.unsafe_store!(Ptr{jlwrap_t}(RTYPEDDATA_DATA(obj)), jlwrap_t(obj, x))
  gcguard[obj] = x
  return obj
end

function jlwrap_call(argc::Cint, argv::Ptr{RbPtr}, obj::RbPtr)::RbPtr
  # TODO: process arguments
  data = Base.unsafe_load(Ptr{jlwrap_t}(RTYPEDDATA_DATA(obj)))
  res = RubyObject(data.value())
  return res.o
end

function jlwrap_inspect(obj::RbPtr)::RbPtr
  data = Base.unsafe_load(Ptr{jlwrap_t}(RTYPEDDATA_DATA(obj)))
  str = string("#<Julia::JuliaBridge::JuliaWrapper ", data.value, ">")
  return RubyObject(str)
end
