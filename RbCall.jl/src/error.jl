rberr_clear() = ccall((@rbsym :rb_set_errinfo), Cvoid, (RbPtr,), RbPtr_Qnil)
