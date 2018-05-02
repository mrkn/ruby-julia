#include "julia_internal.h"

VALUE julia_mJulia;

void
Init_julia(void)
{
  julia_mJulia = rb_define_module("Julia");
  julia_init_libjulia();
}