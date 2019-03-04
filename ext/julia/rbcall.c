#include "julia_internal.h"

jl_module_t *rbjl_rbcall_module;

static jl_function_t *incref_function;
static jl_function_t *decref_function;
static jl_function_t *refcnt_function;

void
rbjl_rbcall_incref(jl_value_t *jlobj)
{
  (void)JULIA_API(jl_call1)(incref_function, jlobj);
}

void
rbjl_rbcall_decref(jl_value_t *jlobj)
{
  (void)JULIA_API(jl_call1)(decref_function, jlobj);
}

long
rbjl_rbcall_refcnt(jl_value_t *jlobj)
{
  jl_value_t *res = JULIA_API(jl_call1)(refcnt_function, jlobj);
  /* TODO: exception handling */
  if (jl_is_int32(res)) {
    return JULIA_API(jl_unbox_int32)(res);
  }
  else if (jl_is_int64(res)) {
    return JULIA_API(jl_unbox_int64)(res);
  }

  return -1;
}

void
rbjl_init_rbcall(void)
{
  VALUE rbcall_dir = rb_ivar_get(rbjl_mJulia, rb_intern("@rbcall_dir"));
  StringValue(rbcall_dir);

  VALUE include_rbcall = rb_sprintf("Base.include(Main, \"%"PRIsVALUE"/src/RbCall.jl\")", rbcall_dir);
  const char *include_rbcall_cstr = StringValueCStr(include_rbcall);
  (void)JULIA_API(jl_eval_string)(include_rbcall_cstr);
  jl_value_t *error = JULIA_API(jl_exception_occurred)();
  if (error) {
    JULIA_API(jl_exception_clear)();

    jl_function_t *sprint = (jl_function_t *)JULIA_API(jl_eval_string)("sprint");
    jl_function_t *showerror = (jl_function_t *)JULIA_API(jl_eval_string)("showerror");

    jl_value_t *res = JULIA_API(jl_call2)(sprint, showerror, error);
    if (res && jl_is_string(res)) {
      const char * c_str = JULIA_API(jl_string_ptr)(res);
      rb_raise(rb_eRuntimeError, "JuliaError: %s", c_str);
    }
  }

  jl_module_t *main_module = *JULIA_API(jl_main_module);
  jl_value_t *rbcall_module = JULIA_API(jl_get_global)(main_module, JULIA_API(jl_symbol)("RbCall"));
  if (!rbcall_module || !jl_is_module(rbcall_module)) {
    rb_raise(rb_eRuntimeError, "RbCall is not a module");
  }
  rbjl_rbcall_module = (jl_module_t *)rbcall_module;
  incref_function = jl_get_function(rbjl_rbcall_module, "_incref");
  decref_function = jl_get_function(rbjl_rbcall_module, "_decref");
  refcnt_function = jl_get_function(rbjl_rbcall_module, "_refcnt");
}
