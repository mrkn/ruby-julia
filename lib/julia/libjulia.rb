require 'fiddle'

module Julia
  module LibJulia
    def self.load_lib
      require 'julia/libjulia/finder'
      lib_path = Finder.find_libjulia
      Fiddle::Handle.new(lib_path[0], Fiddle::Handle::RTLD_LAZY | Fiddle::Handle::RTLD_GLOBAL)
    end

    def self.handle
      @handle ||= load_lib
    end
  end
end
