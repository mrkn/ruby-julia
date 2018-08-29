#include "julia_internal.h"

VALUE julia_mJulia;

static void
init_julia(void)
{
  JULIA_API(jl_init)();
}

void
Init_julia(void)
{
  julia_mJulia = rb_define_module("Julia");

  julia_init_libjulia();

  init_julia();
}
