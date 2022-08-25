const mJulia = RbNULL()
const mJuliaBridge = RbNULL()
const cJuliaWrapper = RbNULL()

function jlwrap_init()
  copy!(mJulia, rb_define_module("Julia"))
  copy!(mJuliaBridge, rb_define_module_under(mJulia, "JuliaBridge"))
  copy!(cJuliaWrapper, rb_define_class_under(mJuliaBridge, "JuliaWrapper", rb_cObject))

  jlwrap_free_cfunc = @cfunction(jlwrap_free, Cvoid, (Ptr{jlwrap_t},))
  jlwrap_size_cfunc = @cfunction(jlwrap_size, Csize_t, (Ptr{jlwrap_t},))
  jlwrap_data_type[] = rb_data_type_t(jlwrap_type_name; dfree=jlwrap_free_cfunc, dsize=jlwrap_size_cfunc)

  rb_define_method(cJuliaWrapper, "call", jlwrap_call, -1)
  rb_define_method(cJuliaWrapper, "inspect", jlwrap_inspect, 0)

  rb_define_method(cJuliaWrapper, "==", jlwrap_eq, 1)
end

function __init__()
  rv = ccall(@rbsym(:ruby_setup), Cint, ())
  if rv != 0
    error("Unable to setup Ruby VM")
  end

  copy!(rb_cObject, RubyObject(Base.unsafe_load(@rbglobalobj :rb_cObject)))

  jlwrap_init()
end
