__precompile__()

module RbCall

export _refcnt, _incref, _decref, gc_guard_references

#########################################################################

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

#########################################################################

end # module RbCall
