module Julia
  def self.const_missing(name)
    case name
    when :JULIA_VERSION
      Julia.init
      const_get(name)
    else
      super
    end
  end

  module LibJulia
    def self.const_missing(name)
      case name
      when :JULIA_VERSION
        Julia.init
        const_get(name)
      else
        super
      end
    end
  end

  def self.init(julia = ENV['JULIA'])
    return false if LibJulia.instance_variable_defined? :@handle
    class << Julia
      remove_method :const_missing
    end
    class << Julia::LibJulia
      remove_method :const_missing
    end

    LibJulia.instance_variable_set :@handle, LibJulia::Finder.find_libjulia(julia)
    class << LibJulia
      undef_method :handle
      attr_reader :handle
    end

    begin
      major, minor, _ = RUBY_VERSION.split('.')
      require "#{major}.#{minor}/julia.so"
    rescue LoadError
      require 'julia.so'
    end

    const_set(:JULIA_VERSION, LibJulia::JULIA_VERSION)
    true
  end
end
