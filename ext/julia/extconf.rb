require 'mkmf'

dir_config('julia')
have_header('julia.h')
have_library('julia')
have_func('jl_init')

create_makefile('julia')
