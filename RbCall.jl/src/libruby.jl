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

rb_cObject = Base.unsafe_load(@rbglobalobj :rb_cObject)

rb_define_class_under(outer::VALUE, name::String, klass::VALUE)::VALUE =
  ccall((@rbsym :rb_define_class_under), VALUE, (VALUE, Cstring, VALUE), outer, name, klass)

rb_define_module_under(outer::VALUE, name::String)::VALUE =
  ccall((@rbsym :rb_define_module_under), VALUE, (VALUE, Cstring), outer, name)

rb_define_module(name::String)::VALUE =
  ccall((@rbsym :rb_define_module), VALUE, (Cstring, ), name)

function ruby_method_function(func, arity)
  if arity == -1
    @cfunction($func, VALUE, (Cint, Ptr{VALUE}, VALUE))
  else
    cfunc_expr = :(@cfunction($func, VALUE, (VALUE,)))
    arg_types = cfunc_expr.args[5].args
    for _ in 1:(arity)
      push!(arg_types, :VALUE)
    end
    cfunc_expr.args[2] = LineNumberNode(cfunc_expr.args[2].line + 7,
                                        cfunc_expr.args[2].file)
    eval(cfunc_expr)
  end
end

function rb_define_method(klass::VALUE, name::String, func::Function, arity::Int)
  ccall(
      (@rbsym :rb_define_method),
      Cvoid,
      (VALUE, Cstring, Ptr{Cvoid}, Cint),
      klass,
      name,
      ruby_method_function(func, arity),
      arity
  )
end

function RTYPEDDATA_DATA(obj::VALUE)
  ptr = Ptr{RTypedData}(obj)
  offset = fieldoffset(RTypedData, 5)  # offset of data
  Base.unsafe_load(Ptr{Ptr{Cvoid}}(ptr + offset))
end

function TypedData_Make_Struct(klass::VALUE, type::Type, data_type::Ref{rb_data_type_t})
  ccall(
      (@rbsym :rb_data_typed_object_zalloc),
      VALUE,
      (VALUE, Csize_t, Ref{rb_data_type_t}),
      klass, sizeof(type), data_type
  )
end
