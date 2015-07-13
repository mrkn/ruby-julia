require 'julia'

Julia.init(ENV['JULIA_HOME'])
Julia.eval_string('Pkg.status()')
