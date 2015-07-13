#include <julia.h>
#include <ruby.h>

VALUE rbjl_mJulia;

static VALUE
rbjl_julia_s_init(VALUE mod, VALUE home)
{
    SafeStringValue(home);
    jl_init(NIL_P(home) ? NULL : StringValueCStr(home));
    return mod;
}

static VALUE
rbjl_julia_s_eval_string(VALUE mod, VALUE str)
{
    SafeStringValue(str);
    jl_eval_string(StringValueCStr(str));

    return mod;
}

void
Init_julia(void)
{
    rbjl_mJulia = rb_define_module("Julia");

    rb_define_module_function(rbjl_mJulia, "init", rbjl_julia_s_init, 1);
    rb_define_module_function(rbjl_mJulia, "eval_string", rbjl_julia_s_eval_string, 1);
}
