#include "julia_internal.h"

VALUE rbjl_cJuliaValuePtr;

static void
rbjl_value_ptr_free(void *ptr)
{
  jl_value_t *jlobj = ptr;
  rbjl_rbcall_decref(jlobj);
}

static size_t
rbjl_value_ptr_memsize(void const *ptr)
{
  /* FIXME */
  return 0;
}

const rb_data_type_t rbjl_value_ptr_data_type = {
  "Julia::ValuePtr",
  { 0, rbjl_value_ptr_free, rbjl_value_ptr_memsize, },
#ifdef RUBY_TYPED_FREE_IMMEDIATELY
  0, 0, RUBY_TYPED_FREE_IMMEDIATELY
#endif
};

VALUE
rbjl_value_ptr_new(jl_value_t *jlobj)
{
  VALUE rbobj = TypedData_Wrap_Struct(rbjl_cJuliaValuePtr, &rbjl_value_ptr_data_type, jlobj);
  rbjl_rbcall_incref(jlobj);
  return rbobj;
}

static VALUE
value_ptr_refcnt(VALUE self)
{
  jl_value_t *value;
  TypedData_Get_Struct(self, jl_value_t, &rbjl_value_ptr_data_type, value);
  long refcnt = rbjl_rbcall_refcnt(value);
  return LONG2NUM(refcnt);
}

void
rbjl_init_value_ptr(void)
{
  rbjl_cJuliaValuePtr = rb_define_class_under(rbjl_mJulia, "ValuePtr", rb_cObject);
  rb_define_method(rbjl_cJuliaValuePtr, "__refcnt__", value_ptr_refcnt, 0);
}
