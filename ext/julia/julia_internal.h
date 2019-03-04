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

/* from src/support/htable.h */

#define HT_N_INLINE 32

typedef struct {
    size_t size;
    void **table;
    void *_space[HT_N_INLINE];
} htable_t;

/* from src/support/arraylist.h */

#define AL_N_INLINE 29

typedef struct {
    size_t len;
    size_t max;
    void **items;
    void *_space[AL_N_INLINE];
} arraylist_t;

/* from src/julia.h */

typedef struct _jl_value_t jl_value_t;
typedef struct _jl_taggedvalue_t jl_taggedvalue_t;

typedef jl_value_t jl_function_t;

typedef struct _jl_sym_t {
    JL_DATA_TYPE
    struct _jl_sym_t *left;
    struct _jl_sym_t *right;
    uintptr_t hash;
} jl_sym_t;

typedef struct {
    JL_DATA_TYPE
    size_t length;
} jl_svec_t;

typedef struct {
    uint32_t nfields;
    uint32_t alignment : 9;
    uint32_t haspadding : 1;
    uint32_t npointers : 20;
    uint32_t fielddesc_type : 2;
} jl_datatype_layout_t;

typedef struct {
    JL_DATA_TYPE
    jl_sym_t *name;
    struct _jl_module_t *module;
    jl_svec_t *names;
    jl_value_t *wrapper;
    jl_svec_t *cache;
    jl_svec_t *linearcache;
    intptr_t hash;
    struct _jl_methtable_t *mt;
} jl_typename_t;

typedef struct _jl_datatype_t {
    JL_DATA_TYPE
    jl_typename_t *name;
    struct _jl_datatype_t *super;
    jl_svec_t *parameters;
    jl_svec_t *types;
    jl_svec_t *names;
    jl_value_t *instance;
    const jl_datatype_layout_t *layout;
    int32_t size;
    int32_t ninitialized;
    uint32_t uid;
    uint8_t abstract;
    uint8_t mutabl;
    uint8_t hasfreetypevars;
    uint8_t isconcretetype;
    uint8_t isdispatchtuple;
    uint8_t isbitstype;
    uint8_t zeroinit;
    uint8_t isinlinealloc;
    void *struct_decl;
    void *ditype;
} jl_datatype_t;

typedef struct {
    uint64_t hi;
    uint64_t lo;
} jl_uuid_t;

typedef struct _jl_module_t {
    JL_DATA_TYPE
    jl_sym_t *name;
    struct _jl_module_t *parent;
    htable_t bindings;
    arraylist_t usings;  // modules with all bindings potentially imported
    uint64_t build_id;
    jl_uuid_t uuid;
    size_t primary_world;
    uint32_t counter;
    int32_t nospecialize;  // global bit flags: initialization for new methods
    uint8_t istopmod;
} jl_module_t;

struct rbjl_api_table {
  int (* jl_is_initialized)(void);
  void (* jl_init)(void);
  char const * (* jl_ver_string)(void);
  jl_datatype_t **jl_bool_type;
  jl_datatype_t **jl_char_type;
  jl_datatype_t **jl_string_type;
  jl_datatype_t **jl_int8_type;
  jl_datatype_t **jl_uint8_type;
  jl_datatype_t **jl_int16_type;
  jl_datatype_t **jl_uint16_type;
  jl_datatype_t **jl_int32_type;
  jl_datatype_t **jl_uint32_type;
  jl_datatype_t **jl_int64_type;
  jl_datatype_t **jl_uint64_type;
  jl_datatype_t **jl_float16_type;
  jl_datatype_t **jl_float32_type;
  jl_datatype_t **jl_float64_type;
  jl_datatype_t **jl_module_type;

  jl_module_t **jl_main_module;
  jl_module_t **jl_base_module;

  jl_value_t * (* jl_call1)(jl_function_t *f, jl_value_t *a);
  jl_value_t * (* jl_call2)(jl_function_t *f, jl_value_t *a, jl_value_t *b);
  jl_value_t * (* jl_exception_occurred)(void);
  void (* jl_exception_clear)(void);
  jl_value_t * (* jl_eval_string)(const char *str);
  jl_value_t * (* jl_get_global)(jl_module_t *m, jl_sym_t *var);
  jl_sym_t * (* jl_symbol)(const char *str);
  jl_value_t * (* jl_typeof)(jl_value_t *v);
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

struct rbjl_api_table *rbjl_get_api_table(void);
#define JULIA_API(name) (rbjl_get_api_table()->name)

#define jl_typeis(v,t) (JULIA_API(jl_typeof)(v)==(jl_value_t*)(t))

// basic predicates -----------------------------------------------------------
#define jl_is_nothing(v)     (((jl_value_t*)(v)) == ((jl_value_t*)jl_nothing))
#define jl_is_tuple(v)       (((jl_datatype_t*)JULIA_API(jl_typeof)(v))->name == *JULIA_API(jl_tuple_typename))
#define jl_is_svec(v)        jl_typeis(v,*JULIA_API(jl_simplevector_type))
#define jl_is_simplevector(v) jl_is_svec(v)
#define jl_is_datatype(v)    jl_typeis(v,*JULIA_API(jl_datatype_type))
#define jl_is_mutable(t)     (((jl_datatype_t*)t)->mutabl)
#define jl_is_mutable_datatype(t) (jl_is_datatype(t) && (((jl_datatype_t*)t)->mutabl))
#define jl_is_immutable(t)   (!((jl_datatype_t*)t)->mutabl)
#define jl_is_immutable_datatype(t) (jl_is_datatype(t) && (!((jl_datatype_t*)t)->mutabl))
#define jl_is_uniontype(v)   jl_typeis(v,*JULIA_API(jl_uniontype_type))
#define jl_is_typevar(v)     jl_typeis(v,*JULIA_API(jl_tvar_type))
#define jl_is_unionall(v)    jl_typeis(v,*JULIA_API(jl_unionall_type))
#define jl_is_typename(v)    jl_typeis(v,*JULIA_API(jl_typename_type))
#define jl_is_int8(v)        jl_typeis(v,*JULIA_API(jl_int8_type))
#define jl_is_int16(v)       jl_typeis(v,*JULIA_API(jl_int16_type))
#define jl_is_int32(v)       jl_typeis(v,*JULIA_API(jl_int32_type))
#define jl_is_int64(v)       jl_typeis(v,*JULIA_API(jl_int64_type))
#define jl_is_uint8(v)       jl_typeis(v,*JULIA_API(jl_uint8_type))
#define jl_is_uint16(v)      jl_typeis(v,*JULIA_API(jl_uint16_type))
#define jl_is_uint32(v)      jl_typeis(v,*JULIA_API(jl_uint32_type))
#define jl_is_uint64(v)      jl_typeis(v,*JULIA_API(jl_uint64_type))
#define jl_is_float32(v)      jl_typeis(v,*JULIA_API(jl_float32_type))
#define jl_is_float64(v)      jl_typeis(v,*JULIA_API(jl_float64_type))
#define jl_is_bool(v)        jl_typeis(v,*JULIA_API(jl_bool_type))
#define jl_is_symbol(v)      jl_typeis(v,*JULIA_API(jl_sym_type))
#define jl_is_method_instance(v) jl_typeis(v,*JULIA_API(jl_method_instance_type))
#define jl_is_method(v)      jl_typeis(v,*JULIA_API(jl_method_type))
#define jl_is_module(v)      jl_typeis(v,*JULIA_API(jl_module_type))
#define jl_is_string(v)      jl_typeis(v,*JULIA_API(jl_string_type))
/*#define jl_is_cpointer(v)    jl_is_cpointer_type(jl_typeof(v))*/
/*#define jl_is_pointer(v)     jl_is_cpointer_type(jl_typeof(v))*/

static inline jl_function_t *
jl_get_function(jl_module_t *m, const char *name)
{
  return (jl_function_t*)JULIA_API(jl_get_global)(m, JULIA_API(jl_symbol)(name));
}

void rbjl_init_libjulia(void);
void rbjl_init_rbcall(void);
void rbjl_init_value_ptr(void);

void rbjl_rbcall_incref(jl_value_t *value);
void rbjl_rbcall_decref(jl_value_t *value);
long rbjl_rbcall_refcnt(jl_value_t *jlobj);

VALUE rbjl_value_ptr_new(jl_value_t *value);

extern VALUE rbjl_mJulia;
extern VALUE rbjl_mLibJulia;
extern VALUE rbjl_cJuliaValuePtr;

extern jl_module_t *rbjl_rbcall_module;

#endif /* JULIA_INTERNAL_H */
