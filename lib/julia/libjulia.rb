module Julia
  module LibJulia
    require 'julia/libjulia/finder'

    def self.load_lib
      require 'julia/libjulia/finder'
      lib_path = Finder.find_libjulia
      Fiddle::Handle.new(lib_path[0], Fiddle::Handle::RTLD_LAZY | Fiddle::Handle::RTLD_GLOBAL)
    end

    def self.handle
      # NOTE: Julia.init redefine this method.
      #       See julia/init.rb for the detail.
      Julia.init
      handle
    end

    module_function def method_missing(name, *args, **kwargs, &block)
      ::Julia.init
      if respond_to?(name)
        __send__(name, *args, **kwargs, &block)
      else
        super
      end
    end
  end
end
