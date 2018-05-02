#include "julia_internal.h"

VALUE julia_mLibJulia;
VALUE julia_eAPINotFound;
struct julia_api_table api_table;
jl_value_t *ans;
const char *type_name;
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
  INIT_API_TABLE_ENTRY(jl_is_initialized);
  INIT_API_TABLE_ENTRY(jl_eval_string);
  INIT_API_TABLE_ENTRY(jl_init);
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
}

static VALUE
jl_eval_string(VALUE handle, VALUE arg)
{
  Check_Type(arg, T_STRING);
  ans = JULIA_API(jl_eval_string)(StringValuePtr(arg));
  type_name = JULIA_API(jl_typeof_str)(ans);
  if (!strcmp(type_name, "String")) {
    return rb_str_new2(JULIA_API(jl_string_ptr)(ans));
  }
  if (!strcmp(type_name, "Bool")) {
    ans_bool = JULIA_API(jl_unbox_bool)(ans);
    if (ans_bool == 1){
      return Qtrue;
    }else{
      return Qfalse;
    }
  }
  if (!strcmp(type_name, "Int8")) {
    return INT2NUM(JULIA_API(jl_unbox_int8)(ans));
  }
  if (!strcmp(type_name, "UInt8")) {
    return INT2NUM(JULIA_API(jl_unbox_uint8)(ans));
  }
  if (!strcmp(type_name, "Int16")) {
    return INT2NUM(JULIA_API(jl_unbox_int16)(ans));
  }
  if (!strcmp(type_name, "UInt16")) {
    return INT2NUM(JULIA_API(jl_unbox_uint16)(ans));
  }
  if (!strcmp(type_name, "Int32")) {
    return INT2NUM(JULIA_API(jl_unbox_int32)(ans));
  }
  if (!strcmp(type_name, "UInt32")) {
    return INT2NUM(JULIA_API(jl_unbox_uint32)(ans));
  }
  if (!strcmp(type_name, "Int64")) {
    return INT2NUM(JULIA_API(jl_unbox_int64)(ans));
  }
  if (!strcmp(type_name, "UInt64")) {
    return INT2NUM(JULIA_API(jl_unbox_uint64)(ans));
  }
  return rb_str_new2(type_name);
}

void
julia_init_libjulia(void)
{
  VALUE handle;
  julia_mLibJulia = rb_const_get_at(julia_mJulia, rb_intern("LibJulia"));
  handle = rb_funcallv(julia_mLibJulia, rb_intern("handle"), 0, 0);
  rb_define_module_function(julia_mLibJulia, "jl_eval_string", jl_eval_string, 1);
  init_api_table(handle);

  if (JULIA_API(jl_is_initialized)() == 0) {
    JULIA_API(jl_init)();
  }
}