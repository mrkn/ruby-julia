require 'fiddle'

module Julia
  module LibJulia
    def self.load_lib
      Fiddle::Handle.new('libjulia.so.0.6', Fiddle::Handle::RTLD_LAZY | Fiddle::Handle::RTLD_GLOBAL)
    end

    def self.handle
      @handle ||= load_lib
    end
  end
end
