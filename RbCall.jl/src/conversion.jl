function julia_object_wrapper_new(value::Any)
  rb_cObject = cglobal(:rb_cObject, Ptr{Cvoid})
  ptr = ccall(:rb_class_new_instance, Ptr{Cvoid}, (Cint, Ptr{Cvoid}, Ptr{Cvoid}), 0, C_NULL, rb_cObject)
  obj = RubyObject(ptr)

end

function convert(::VALUE, x::Integer)
  if RB_FIXABLE(x)
    # to Fixnum
    return RB_INT2FIX(x)
  elseif typemin(Clonglong) <= x < 0
    return ccall(:rb_ll2inum, VALUE, (Clonglong,), Clonglong(x))
  elseif 0 <= x <= typemax(Culonglong)
    return ccall(:rb_ull2big, VALUE, (Culonglong,), Culonglong(x))
  else
    return RUBY_Qnil
    # TODO
  end
end
