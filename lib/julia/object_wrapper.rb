module Julia
  module ObjectWrapper
    def initialize(value_ptr)
      @__value_ptr__ = value_ptr
    end

    attr_reader :__value_ptr__
  end
end
