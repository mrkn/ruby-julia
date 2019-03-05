#include "julia_internal.h"

VALUE rbjl_mLibJulia;
VALUE rbjl_eAPINotFound;
struct rbjl_api_table api_table;

struct rbjl_api_table *
rbjl_get_api_table(void)
{
  return &api_table;
}

struct lookup_api_args {
  VALUE handle;
  char const *name;
};

static VALUE
lookup_libjulia_api_0(struct lookup_api_args *args)
{
  return rb_funcall(args->handle, rb_intern("sym"), 1, rb_str_new2(args->name));
}

static void *
lookup_libjulia_api(VALUE handle, char const *name)
{
  struct lookup_api_args arg;
  VALUE addr;
  int state;

  arg.handle = handle;
  arg.name = name;
  addr = rb_protect((VALUE (*)(VALUE))lookup_libjulia_api_0, (VALUE)&arg, &state);
  return (state || NIL_P(addr)) ? NULL : NUM2PTR(addr);
}

static void
init_api_table(VALUE handle)
{
#define LOOKUP_API_ENTRY(api_name) lookup_libjulia_api(handle, #api_name)
#define CHECK_API_ENTRY(api_name) (LOOKUP_API_ENTRY(api_name) != NULL)
#define INIT_API_TABLE_ENTRY2(member_name, api_name) do { \
    void *fptr = LOOKUP_API_ENTRY(api_name); \
    if (!fptr) { \
      rb_raise(rbjl_eAPINotFound, "Unable to find the required symbol in libjulia: %s", #api_name); \
    } \
    ((api_table).member_name) = fptr; \
  } while (0)
#define INIT_API_TABLE_ENTRY(api_name) INIT_API_TABLE_ENTRY2(api_name, api_name)

  if (CHECK_API_ENTRY(jl_init)) {
    INIT_API_TABLE_ENTRY(jl_init);
  }
  else {
    INIT_API_TABLE_ENTRY2(jl_init, jl_init__threading);
  }

  INIT_API_TABLE_ENTRY(jl_is_initialized);
  INIT_API_TABLE_ENTRY(jl_ver_string);

  INIT_API_TABLE_ENTRY(jl_bool_type);
  INIT_API_TABLE_ENTRY(jl_char_type);
  INIT_API_TABLE_ENTRY(jl_string_type);
  INIT_API_TABLE_ENTRY(jl_int8_type);
  INIT_API_TABLE_ENTRY(jl_uint8_type);
  INIT_API_TABLE_ENTRY(jl_int16_type);
  INIT_API_TABLE_ENTRY(jl_uint16_type);
  INIT_API_TABLE_ENTRY(jl_int32_type);
  INIT_API_TABLE_ENTRY(jl_uint32_type);
  INIT_API_TABLE_ENTRY(jl_int64_type);
  INIT_API_TABLE_ENTRY(jl_uint64_type);
  INIT_API_TABLE_ENTRY(jl_float16_type);
  INIT_API_TABLE_ENTRY(jl_float32_type);
  INIT_API_TABLE_ENTRY(jl_float64_type);
  INIT_API_TABLE_ENTRY(jl_module_type);

  INIT_API_TABLE_ENTRY(jl_main_module);
  INIT_API_TABLE_ENTRY(jl_base_module);

  INIT_API_TABLE_ENTRY(jl_call1);
  INIT_API_TABLE_ENTRY(jl_call2);
  INIT_API_TABLE_ENTRY(jl_exception_occurred);
  INIT_API_TABLE_ENTRY(jl_exception_clear);
  INIT_API_TABLE_ENTRY(jl_get_global);
  INIT_API_TABLE_ENTRY(jl_symbol);
  INIT_API_TABLE_ENTRY(jl_eval_string);
  INIT_API_TABLE_ENTRY(jl_typeof);
  INIT_API_TABLE_ENTRY(jl_typeof_str);
  INIT_API_TABLE_ENTRY(jl_string_ptr);
  INIT_API_TABLE_ENTRY(jl_unbox_bool);
  INIT_API_TABLE_ENTRY(jl_unbox_int8);
  INIT_API_TABLE_ENTRY(jl_unbox_uint8);
  INIT_API_TABLE_ENTRY(jl_unbox_int16);
  INIT_API_TABLE_ENTRY(jl_unbox_uint16);
  INIT_API_TABLE_ENTRY(jl_unbox_int32);
  INIT_API_TABLE_ENTRY(jl_unbox_uint32);
  INIT_API_TABLE_ENTRY(jl_unbox_int64);
  INIT_API_TABLE_ENTRY(jl_unbox_uint64);
  INIT_API_TABLE_ENTRY(jl_unbox_float32);
  INIT_API_TABLE_ENTRY(jl_unbox_float64);
}

static VALUE
jl_eval_string(VALUE handle, VALUE arg, VALUE raw_p)
{
  Check_Type(arg, T_STRING);
  jl_value_t *ans = JULIA_API(jl_eval_string)(StringValuePtr(arg));
  /* TODO: exception handling */

  if (RTEST(raw_p)) {
    return rbjl_value_ptr_new(ans);
  }

  if (jl_is_string(ans)) {
    /* TODO: encoding */
    return rb_str_new2(JULIA_API(jl_string_ptr)(ans));
  }
  if (jl_is_bool(ans)) {
    int ans_bool = JULIA_API(jl_unbox_bool)(ans);
    if (ans_bool == 1){
      return Qtrue;
    }
    else {
      return Qfalse;
    }
  }
  if (jl_is_int8(ans)) {
    return INT2NUM(JULIA_API(jl_unbox_int8)(ans));
  }
  if (jl_is_uint8(ans)) {
    return INT2NUM(JULIA_API(jl_unbox_uint8)(ans));
  }
  if (jl_is_int16(ans)) {
    return INT2NUM(JULIA_API(jl_unbox_int16)(ans));
  }
  if (jl_is_uint16(ans)) {
    return INT2NUM(JULIA_API(jl_unbox_uint16)(ans));
  }
  if (jl_is_int32(ans)) {
    return INT2NUM(JULIA_API(jl_unbox_int32)(ans));
  }
  if (jl_is_uint32(ans)) {
    return INT2NUM(JULIA_API(jl_unbox_uint32)(ans));
  }
  if (jl_is_int64(ans)) {
    return INT2NUM(JULIA_API(jl_unbox_int64)(ans));
  }
  if (jl_is_uint64(ans)) {
    return INT2NUM(JULIA_API(jl_unbox_uint64)(ans));
  }
  if (jl_is_float32(ans)) {
    return DBL2NUM(JULIA_API(jl_unbox_float32)(ans));
  }
  if (jl_is_float64(ans)) {
    return DBL2NUM(JULIA_API(jl_unbox_float64)(ans));
  }
  return rb_str_new2(JULIA_API(jl_typeof_str)(ans));
}

static void
define_JULIA_VERSION(void)
{
  char const *version = JULIA_API(jl_ver_string)();
  rb_define_const(rbjl_mLibJulia, "JULIA_VERSION", rb_usascii_str_new_static(version, strlen(version)));
}

void
rbjl_init_libjulia(void)
{
  VALUE handle;
  rbjl_mLibJulia = rb_const_get_at(rbjl_mJulia, rb_intern("LibJulia"));
  handle = rb_funcall(rbjl_mLibJulia, rb_intern("handle"), 0);
  rb_define_module_function(rbjl_mLibJulia, "jl_eval_string", jl_eval_string, 2);
  init_api_table(handle);

  if (JULIA_API(jl_is_initialized)() == 0) {
    JULIA_API(jl_init)();
  }

  define_JULIA_VERSION();
}
