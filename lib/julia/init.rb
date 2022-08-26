module Julia
  def self.const_missing(name)
    case name
    when :JULIA_VERSION, :ValuePtr
      return const_get(name) if Julia.init
    end
    super
  end

  def self.method_missing(name, *args, **kwargs, &block)
    init
    if respond_to?(name)
      return __send__(name, *args, **kwargs, &block)
    else
      super
    end
  end

  module LibJulia
    def self.const_missing(name)
      case name
      when :JULIA_VERSION
        return const_get(name) if Julia.init
      end
      super
    end

    def self.method_missing(*args)
      return send(*args) if Julia.init
      super
    end
  end

  def self.initialized?
    @initialized
  end

  def self.init(julia = ENV['JULIA'])
    return false if initialized?

    require 'pathname'
    top_dir = Pathname(__dir__).parent.parent
    rbcall_dir = top_dir / "RbCall.jl"
    Julia.instance_variable_set :@rbcall_dir, rbcall_dir.to_s

    LibJulia.instance_variable_set :@handle, LibJulia::Finder.find_libjulia(julia)
    class << LibJulia
      undef_method :handle
      attr_reader :handle
    end

    begin
      require "julia.so"
    rescue LoadError
      ext_dir = File.expand_path("../../../ext/julia", __FILE__)
      $LOAD_PATH.unshift(ext_dir)
      require "julia.so"
    end

    const_set(:JULIA_VERSION, LibJulia::JULIA_VERSION)

    class << Julia
      remove_method :const_missing
      remove_method :method_missing
    end

    class << Julia::LibJulia
      remove_method :const_missing
      remove_method :method_missing
    end

    at_exit {
      LibJulia.jl_atexit_hook(0)
    }

    @initialized = true

    require_relative "bridge"
  end
end
