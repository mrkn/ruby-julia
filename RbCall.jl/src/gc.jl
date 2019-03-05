### GC Guard for Julia objects

const gc_guard_references = Dict{Any,Clong}()

function _refcnt(value::Any)
  return get(gc_guard_references, value , 0)
end

function _incref(value::Any)
  gc_guard_references[value] = _refcnt(value) + 1
  return value
end

function _decref(value::Any)
  if haskey(gc_guard_references, value)
    new_count = _refcnt(value) - 1
    if new_count == 0
      delete!(gc_guard_references, value)
    else
      gc_guard_references[value] = new_count
    end
  end
end

### GC Guard for Ruby objects

gc_guard_table = VALUE(0)

function init_gc_guard_table()
  if gc_guard_table != 0
    return
  end

  gc_guard_table = ccall(:rb_hash_new, VALUE, ())
  mJulia = ccall(:rb_define_module, VALUE, (Cstring,), "Julia")
  id_gc_guard_table = ccall(:rb_intern, ID, (Cstring,), "@gc_guard_table")
  ccall(:rb_ivar_set, VALUE, (VALUE, ID, VALUE), mJulia, id_gc_guard_table, gc_guard_table)
end

function gc_guard_register_(ro::RubyObject)
  cnt = convert(Integer, ccall(:rb_hash_lookup2, VALUE, (VALUE, VALUE, VALUE), gc_guard_table, ro.o, INT2NUM(0)))
  ccall(:rb_hash_aset, VALUE, (VALUE, VALUE, VALUE), gc_guard_table, ro.o, INT2NUM(cnt + 1))
end

function gc_guard_register(ro::RubyObject)
  init_gc_guard_table()
  global gc_guard_register
  gc_guard_register = gc_guard_register_
  gc_guard_register_(ro)
end

function gc_guard_unregister(ro::RubyObject)
  cnt = convert(Integer, ccall(:rb_hash_lookup2, VALUE, (VALUE, VALUE, VALUE), gc_guard_table, ro.o, INT2NUM(0)))
  if cnt <= 1
    ccall(:rb_hash_delete, VALUE, (VALUE, VALUE), gc_guard_table, ro.o)
  else
    ccall(:rb_hash_aset, VALUE, (VALUE, VALUE, VALUE), gc_guard_table, ro.o, INT2NUM(cnt - 1))
  end
end
