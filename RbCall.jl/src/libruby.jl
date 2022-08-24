struct rb_data_type_t
  wrap_struct_name::Cstring  # const char *wrap_struct_name;
  dmark::Ptr{Cvoid}  # RUBY_DATA_FUNC dmark
  dfree::Ptr{Cvoid}  # RUBY_DATA_FUNC dfree
  dsize::Ptr{Cvoid}  # size_t (*dsize)(const void *)
  dcompact::Ptr{Cvoid}  # RUBY_DATA_FUNC dcompact
  reserved::NTuple{1, Ptr{Cvoid}}  # void *reserved[1]
  parent::Ptr{rb_data_type_t}  # const rb_data_type_t *parent;
  data::Ptr{Cvoid}  # void *data;
  flags::VALUE      # VALUE flags;
end

function rb_data_type_t(name::Cstring;
                        dmark::Ptr{Cvoid}=C_NULL,
                        dfree::Ptr{Cvoid}=C_NULL,
                        dsize::Ptr{Cvoid}=C_NULL,
                        dcompact::Ptr{Cvoid}=C_NULL,
                        parent::Ptr{rb_data_type_t}=Ptr{rb_data_type_t}(C_NULL),
                        data::Ptr{Cvoid}=C_NULL,
                        flags::VALUE=VALUE(0))
  rb_data_type_t(name, dmark, dfree, dsize, dcompact, (C_NULL,), parent, data, flags)
end

mutable struct RTypedData
  # RBasic fields
  flags::VALUE
  klass::VALUE

  # RTypedData fields
  type::Ptr{rb_data_type_t}
  typed_flag::VALUE
  data::Ptr{Cvoid}
end

const rb_cObject = RubyObject(RbPtr_Qnil)

rb_define_class_under(outer::RubyObject, name::String, klass::RubyObject)::RubyObject =
  ccall((@rbsym :rb_define_class_under), RbPtr, (RbPtr, Cstring, RbPtr), outer, name, klass)

rb_define_module_under(outer::RubyObject, name::String)::RubyObject =
  ccall((@rbsym :rb_define_module_under), RbPtr, (RbPtr, Cstring), outer, name)

rb_define_module(name::String)::RubyObject =
  ccall((@rbsym :rb_define_module), RbPtr, (Cstring, ), name)

function ruby_method_function(func, arity)
  if arity == -1
    @cfunction($func, RbPtr, (Cint, Ptr{RbPtr}, RbPtr))
  else
    cfunc_expr = :(@cfunction($func, RbPtr, (RbPtr,)))
    arg_types = cfunc_expr.args[5].args
    for _ in 1:(arity)
      push!(arg_types, :RbPtr)
    end
    cfunc_expr.args[2] = LineNumberNode(cfunc_expr.args[2].line + 7,
                                        cfunc_expr.args[2].file)
    eval(cfunc_expr)
  end
end

function rb_define_method(klass::RubyObject, name::String, func::Function, arity::Int)
  ccall(
      (@rbsym :rb_define_method),
      Cvoid,
      (RbPtr, Cstring, Ptr{Cvoid}, Cint),
      klass,
      name,
      ruby_method_function(func, arity),
      arity
  )
end

function RTYPEDDATA_DATA(p::RbPtr)
  ptr = Ptr{RTypedData}(p)
  offset = fieldoffset(RTypedData, 5)  # offset of data
  Base.unsafe_load(Ptr{Ptr{Cvoid}}(ptr + offset))
end

RTYPEDDATA_DATA(obj::RubyObject) = RTYPEDDATA_DATA(obj.o)

function TypedData_Make_Struct(klass::RubyObject, type::Type, data_type::Ref{rb_data_type_t})::RubyObject
  ccall(
      (@rbsym :rb_data_typed_object_zalloc),
      RbPtr,
      (RbPtr, Csize_t, Ref{rb_data_type_t}),
      klass, sizeof(type), data_type
  )
end
