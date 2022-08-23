const RubyNothing = GC.@preserve RubyObject(Base.unsafe_load(unsafe_convert(Ptr{RbPtr}, pointer([RUBY_Qnil]))))

const mJulia = RbNULL()
const mJuliaBridge = RbNULL()
const cJuliaWrapper = RbNULL()

function jlwrap_init()
  copy!(mJulia, rb_define_module("Julia"))
  copy!(mJuliaBridge, rb_define_module_under(mJulia, "JuliaBridge"))
  copy!(cJuliaWrapper, rb_define_class_under(mJuliaBridge, "JuliaWrapper", rb_cObject))

  rb_define_method(cJuliaWrapper, "call", jlwrap_call, -1)
  rb_define_method(cJuliaWrapper, "inspect", jlwrap_inspect, 0)
  #rb_define_method(cJuliaWrapper, "to_s", jlwrap_inspect, 0)
end

function __init__()
  rv = ccall(@rbsym(:ruby_setup), Cint, ())
  if rv != 0
    error("Unable to setup Ruby VM")
  end

  jlwrap_init()
end
