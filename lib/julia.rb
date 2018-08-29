module Julia
  require 'julia/version'
  require 'julia/libjulia'
  require 'julia/init'

  module_function

  def eval(str)
    Julia.init unless LibJulia.respond_to? :jl_eval_string
    LibJulia.jl_eval_string(str)
  end
end
