#include "julia_internal.h"

VALUE julia_mLibJulia;
VALUE julia_eAPINotFound;
struct julia_api_table api_table;
jl_value_t *ans;
int8_t ans_bool;

struct julia_api_table *
julia_get_api_table(void)
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
      rb_raise(julia_eAPINotFound, "Unable to find the required symbol in libjulia: %s", #api_name); \
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

int
jl_typeis(jl_value_t *v, jl_datatype_t *t){
  return ((jl_typename_t *)JULIA_API(jl_typeof)(v) == t->name);
}

int
jl_is_bool(jl_value_t *v)
{
  return jl_typeis(v, JULIA_API(jl_bool_type));
}

int
jl_is_char(jl_value_t *v)
{
  return jl_typeis(v, JULIA_API(jl_char_type));
}

int
jl_is_string(jl_value_t *v)
{
  return jl_typeis(v, JULIA_API(jl_string_type));
}

int
jl_is_int8(jl_value_t *v)
{
  return jl_typeis(v, JULIA_API(jl_int8_type));
}

int
jl_is_uint8(jl_value_t *v)
{
  return jl_typeis(v, JULIA_API(jl_uint8_type));
}

int
jl_is_int16(jl_value_t *v)
{
  return jl_typeis(v, JULIA_API(jl_int16_type));
}

int
jl_is_uint16(jl_value_t *v)
{
  return jl_typeis(v, JULIA_API(jl_uint16_type));
}

int
jl_is_int32(jl_value_t *v)
{
  return jl_typeis(v, JULIA_API(jl_int32_type));
}

int
jl_is_uint32(jl_value_t *v)
{
  return jl_typeis(v, JULIA_API(jl_uint32_type));
}

int
jl_is_int64(jl_value_t *v)
{
  return jl_typeis(v, JULIA_API(jl_int64_type));
}

int
jl_is_uint64(jl_value_t *v)
{
  return jl_typeis(v, JULIA_API(jl_uint64_type));
}

int
jl_is_float16(jl_value_t *v)
{
  return jl_typeis(v, JULIA_API(jl_float16_type));
}

int
jl_is_float32(jl_value_t *v)
{
  return jl_typeis(v, JULIA_API(jl_float32_type));
}

int
jl_is_float64(jl_value_t *v)
{
  return jl_typeis(v, JULIA_API(jl_float64_type));
}

static VALUE
jl_eval_string(VALUE handle, VALUE arg)
{
  Check_Type(arg, T_STRING);
  ans = JULIA_API(jl_eval_string)(StringValuePtr(arg));
  if (jl_is_string(ans)) {
    return rb_str_new2(JULIA_API(jl_string_ptr)(ans));
  }
  if (jl_is_bool(ans)) {
    ans_bool = JULIA_API(jl_unbox_bool)(ans);
    if (ans_bool == 1){
      return Qtrue;
    }else{
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
  rb_define_const(julia_mLibJulia, "JULIA_VERSION", rb_usascii_str_new_static(version, strlen(version)));
}

void
julia_init_libjulia(void)
{
  VALUE handle;
  julia_mLibJulia = rb_const_get_at(julia_mJulia, rb_intern("LibJulia"));
  handle = rb_funcall(julia_mLibJulia, rb_intern("handle"), 0);
  rb_define_module_function(julia_mLibJulia, "jl_eval_string", jl_eval_string, 1);
  init_api_table(handle);

  if (JULIA_API(jl_is_initialized)() == 0) {
    JULIA_API(jl_init)();
  }

  define_JULIA_VERSION();
}
