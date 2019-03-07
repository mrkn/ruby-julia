module Julia
  require 'julia/version'
  require 'julia/libjulia'
  require 'julia/init'

  module_function

  def eval(str, raw: false)
    Julia.init unless defined? Julia::JULIA_VERSION
    LibJulia.jl_eval_string(str, raw)
  end
end
