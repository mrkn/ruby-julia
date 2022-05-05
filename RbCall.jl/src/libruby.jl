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

rb_cObject = Base.unsafe_load(@rbglobalobj :rb_cObject)

rb_define_class_under(outer::VALUE, name::String, klass::VALUE)::VALUE =
  ccall((@rbsym :rb_define_class_under), VALUE, (VALUE, Cstring, VALUE), outer, name, klass)

rb_define_module_under(outer::VALUE, name::String)::VALUE =
  ccall((@rbsym :rb_define_module_under), VALUE, (VALUE, Cstring), outer, name)

rb_define_module(name::String)::VALUE =
  ccall((@rbsym :rb_define_module), VALUE, (Cstring, ), name)
