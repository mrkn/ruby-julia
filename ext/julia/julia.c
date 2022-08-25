#include "julia_internal.h"

VALUE rbjl_mJulia;

void
rbjl_check_julia_exception(const char *message)
{
  jl_value_t *error = JULIA_API(jl_exception_occurred)();
  if (!error) return;

  jl_value_t *backtrace = JULIA_API(jl_eval_string)("stacktrace(catch_backtrace(), true)");

  JULIA_API(jl_exception_clear)();

  jl_value_t *showerror = JULIA_API(jl_eval_string)("showerror");
  jl_function_t *sprint = (jl_function_t *)JULIA_API(jl_eval_string)("sprint");

  jl_value_t *res = JULIA_API(jl_call3)(sprint, showerror, error, backtrace);
  if (res && jl_is_string(res)) {
    const char * c_str = JULIA_API(jl_string_ptr)(res);
    rb_raise(rb_eRuntimeError, "JuliaError: %s (%s)", c_str, message);
  }
}

static void
init_julia(void)
{
  JULIA_API(jl_init)();
}

void
Init_julia(void)
{
  rbjl_mJulia = rb_define_module("Julia");

  rbjl_init_libjulia();

  init_julia();

  rbjl_init_rbcall();
  rbjl_init_value_ptr();
}
