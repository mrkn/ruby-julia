module Julia
  require 'julia/version'
  require 'julia/libjulia'
  require 'julia/init'

  module_function

  def eval(str, raw: false)
    Julia.init unless LibJulia.respond_to? :jl_eval_string
    LibJulia.jl_eval_string(str, raw)
  end
end
