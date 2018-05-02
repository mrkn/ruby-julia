require 'julia/version'

module Julia
  require 'julia/libjulia'
  require 'julia.so'
  class << self
    def eval(src)
      LibJulia.jl_eval_string(src)
    end
  end
end