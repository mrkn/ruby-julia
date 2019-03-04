#include "julia_internal.h"

VALUE rbjl_mJulia;

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
