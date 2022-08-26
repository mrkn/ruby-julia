module Julia
  module_function def eval(src, raw: false)
    LibJulia.jl_eval_string(src, raw)
  end

  module_function def isamodule(name)
    Julia.eval("isa(#{name}, Module)")
  end

  module_function def isdefined(parent, member)
    Julia.eval("isdefined(#{parent}, :(#{member}))")
  end

  class JuliaModule < Module
    def initialize(*args, **kwargs, &block)
      super(*args, **kwargs, &block)
    end

    def names
      jl_path = name.delete_prefix("Julia::")
      jl_path.gsub!("::", ".")
      names = Julia.eval("names(#{jl_path})")
      names.delete(jl_path.rpartition('.')[-1])
      names
    end

    def [](name)
      jl_path = self.name.delete_prefix("Julia::")
      jl_fullname = "#{jl_path}.#{name}"
      case
      when Julia.isamodule(jl_fullname)
        real_name = Julia.fullname(Julia.eval(jl_fullname))
        if _defined?(real_name)
          Julia.load_module(real_name)
        end
      when Julia.isdefined(jl_path, name)
        Julia.eval(jl_fullname)
      else
        raise KeyError.new("#{name} is not defined in #{self.name} module", key: name)
      end
    end
  end

  class JuliaMainModule < JuliaModule
  end

  Main = JuliaMainModule.new

  Base = JuliaModule.new

  Julia.eval("using InteractiveUtils")
  InteractiveUtils = JuliaModule.new

  Base::Float64 = eval("Float64")

  RbCall = JuliaModule.new

  def self.load_module(path)
    path = path.is_a?(Symbol) ? path.to_s : path.to_str
    julia_path = path.delete_prefix("Julia::")
    julia_path.gsub!("::", ".")
    if julia_path == "Main"
      Main
    # else Julia.function?(julia_path)
    # Julia.eval(julia_path)
    end

    begin
      Julia.eval("import #{julia_path.split(".", 2)[0]}")
    rescue Exception # JuliaError
      # ignored
    else
      if Julia.module?(julia_path)
        # TODO: recursively resolve modules and substitute a new wrapper
      end
    end
  end

  module_function def tuple(*values)
    Julia::Base["tuple"].(*values)
  end

  module_function def typeof(x)
    Julia::Base["typeof"].(x)
  end

  module Base
    module_function def zeros(type, *dims)
      Julia::Base["zeros"].(type, *dims)
    end
  end
end
