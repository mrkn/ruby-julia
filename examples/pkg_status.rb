require 'julia'

Julia.init(ENV['JULIA_HOME'])
Julia.eval('Pkg.status()')
