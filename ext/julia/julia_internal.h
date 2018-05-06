#ifndef JULIA_INTERNAL_H
#define JULIA_INTERNAL_H 1
#define JL_DATA_TYPE

#ifdef __cplusplus
extern "C" {
#if 0
} /* satisfy cc-mode */
#endif
#endif

#include <ruby.h>

#if SIZEOF_LONG == SIZEOF_VOIDP
# define PTR2NUM(x)   (LONG2NUM((long)(x)))
# define NUM2PTR(x)   ((void*)(NUM2ULONG(x)))
#elif SIZEOF_LONG_LONG == SIZEOF_VOIDP
# define PTR2NUM(x)   (LL2NUM((LONG_LONG)(x)))
# define NUM2PTR(x)   ((void*)(NUM2ULL(x)))
#else
# error ---->> ruby requires sizeof(void*) == sizeof(long) or sizeof(LONG_LONG) to be compiled. <<----
#endif

typedef struct _jl_value_t jl_value_t;
typedef struct _jl_taggedvalue_t jl_taggedvalue_t;

struct julia_api_table {
  int (* jl_is_initialized)(void);
  void (* jl_init)(void);
  jl_value_t * (* jl_eval_string)(const char *str);
  const char * (* jl_typeof_str)(jl_value_t *v);
  const char * (* jl_string_ptr)(jl_value_t *s);
  int8_t (* jl_unbox_bool)(jl_value_t *v);
  int8_t (* jl_unbox_int8)(jl_value_t *v);
  uint8_t (* jl_unbox_uint8)(jl_value_t *v);
  int16_t (* jl_unbox_int16)(jl_value_t *v);
  uint16_t (* jl_unbox_uint16)(jl_value_t *v);
  int32_t (* jl_unbox_int32)(jl_value_t *v);
  uint32_t (* jl_unbox_uint32)(jl_value_t *v);
  int64_t (* jl_unbox_int64)(jl_value_t *v);
  uint64_t (* jl_unbox_uint64)(jl_value_t *v);
  float (* jl_unbox_float32)(jl_value_t *v);
  double (* jl_unbox_float64)(jl_value_t *v);
};

struct julia_api_table *julia_get_api_table(void);
#define JULIA_API(name) (julia_get_api_table()->name)

void julia_init_libjulia(void);

extern VALUE julia_mJulia;
extern VALUE julia_mLibJulia;
#endif /* JULIA_INTERNAL_H */