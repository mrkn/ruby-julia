mutable struct jlwrap_t
  rbobj::VALUE  # for finalizer
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

const mJulia = rb_define_module("Julia")
const mJuliaBridge = rb_define_module_under(mJulia, "JuliaBridge")
const cJuliaWrapper = rb_define_class_under(mJuliaBridge, "JuliaWrapper", rb_cObject)

function jlwrap_new(x::Any)
  obj = TypedData_Make_Struct(cJuliaWrapper, jlwrap_t, jlwrap_data_type)
  Base.unsafe_store!(Ptr{jlwrap_t}(RTYPEDDATA_DATA(obj)), jlwrap_t(obj, x))
  gcguard[obj] = x
  return obj
end

function jlwrap_call(argc::Cint, argv::Ptr{VALUE}, obj::VALUE)::VALUE
  # TODO
  data = Base.unsafe_load(Ptr{jlwrap_t}(RTYPEDDATA_DATA(obj)))
  res = data.value()
  return convert(VALUE, res)
end

rb_define_method(cJuliaWrapper, "call", jlwrap_call, -1)
