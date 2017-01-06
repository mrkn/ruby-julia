require 'julia/version'
require 'ffi'

module Julia
  module LibJulia
    class JlTaggedvalueBits < FFI::Struct
      layout gc: :uintptr_t
    end

    class JlTaggedvalueT < FFI::Union
      layout header: :uintptr_t,
             next:   :pointer,
             type:   :pointer,
             bits:   JlTaggedvalueBits
    end

    class << self
      def jl_astaggedvalue(jl_value_ptr)
        addr = jl_value_ptr.address - JlTaggedvalueT.size
        JlTaggedvalueT.new(FFI::Pointer.new(addr))
      end

      def jl_typeof(jl_value_ptr)
        addr = jl_astaggedvalue(jl_value_ptr)[:header] & ~15
        FFI::Pointer.new(addr)
      end

      def jl_typeis(jl_value, jl_datatype)
        jl_typeof(jl_value) == jl_datatype
      end

      private

      def __init__(julia=nil)
        julia ||= 'julia'

        extend FFI::Library

        if is_current_process_julia?
          ffi_lib FFI::CURRENT_PROCESS
        else
          julia_home, libjulia_path, = investigate_julia(julia)
          unless File.file?(libjulia_path)
            raise LibJuliaNotFound, "Julia library (libjulia) not found: #{libjulia_path}"
          end

          ffi_lib_flags :lazy, :global
          ffi_lib libjulia_path
        end

        attach_function :jl_is_initialized, [], :int

        if jl_is_initialized().zero?
          attach_function :jl_init, [:string], :void
          jl_init(julia_home)

          attach_function :jl_atexit_hook, [:int], :void
          at_exit { jl_atexit_hook(0) }
        end

        attach_function :jl_eval_string, [:string], :pointer

        attach_function :jl_unbox_bool, [:pointer], :int8_t
        attach_function :jl_unbox_int8, [:pointer], :int8_t
        attach_function :jl_unbox_uint8, [:pointer], :uint8_t
        attach_function :jl_unbox_int16, [:pointer], :int16_t
        attach_function :jl_unbox_uint16, [:pointer], :uint16_t
        attach_function :jl_unbox_int32, [:pointer], :int32_t
        attach_function :jl_unbox_uint32, [:pointer], :uint32_t
        attach_function :jl_unbox_int64, [:pointer], :int64_t
        attach_function :jl_unbox_uint64, [:pointer], :uint64_t
        attach_function :jl_unbox_float32, [:pointer], :float
        attach_function :jl_unbox_float64, [:pointer], :double
        attach_function :jl_unbox_voidpointer, [:pointer], :pointer

        attach_variable :jl_bool_type, :pointer
        attach_variable :jl_int8_type, :pointer
        attach_variable :jl_uint8_type, :pointer
        attach_variable :jl_int16_type, :pointer
        attach_variable :jl_uint16_type, :pointer
        attach_variable :jl_int32_type, :pointer
        attach_variable :jl_uint32_type, :pointer
        attach_variable :jl_int64_type, :pointer
        attach_variable :jl_uint64_type, :pointer
        attach_variable :jl_float32_type, :pointer
        attach_variable :jl_float64_type, :pointer
        attach_variable :jl_datatype_type, :pointer

        [ :bool, :int8, :uint8,  :int16, :uint16, :int32, :uint32,
          :int64, :uint64, :float32, :float64, :datatype
        ].each do |typename|
          type = __send__ :"jl_#{typename}_type"
          define_singleton_method(:"jl_is_#{typename}") do |jl_value|
            jl_typeis(jl_value, type)
          end
        end

        true
      end

      def is_current_process_julia?
        !!current_process_as_ffi_dynamic_library.find_function('jl_initialized')
      end

      def current_process_as_ffi_dynamic_library
        FFI::DynamicLibrary.open(
          nil,
          FFI::DynamicLibrary::RTLD_LAZY | FFI::DynamicLibrary::RTLD_LOCAL
        )
      end

      def investigate_julia(julia)
        [].tap do |info|
          IO.popen([julia, '-e', julia_investigator_src], 'r:utf-8') do |io|
            while line = io.gets
              info << line.chomp
            end
          end
        end
      end

      def julia_investigator_src
        <<-JULIA
          println(JULIA_HOME)
          println(Libdl.dlpath(string("lib", Base.julia_exename())))
        JULIA
      end
    end

    __init__(ENV['JULIA'])
  end

  class << self
    def eval(src)
      ans = LibJulia.jl_eval_string(src.encode(Encoding::UTF_8))
      case
      when LibJulia.jl_is_bool(ans)
        return 0 != LibJulia.jl_unbox_bool(ans)
      when LibJulia.jl_is_int8(ans)
        return LibJulia.jl_unbox_int8(ans)
      when LibJulia.jl_is_uint8(ans)
        return LibJulia.jl_unbox_uint8(ans)
      when LibJulia.jl_is_int16(ans)
        return LibJulia.jl_unbox_int16(ans)
      when LibJulia.jl_is_uint16(ans)
        return LibJulia.jl_unbox_uint16(ans)
      when LibJulia.jl_is_int32(ans)
        return LibJulia.jl_unbox_int32(ans)
      when LibJulia.jl_is_uint32(ans)
        return LibJulia.jl_unbox_uint32(ans)
      when LibJulia.jl_is_int64(ans)
        return LibJulia.jl_unbox_int64(ans)
      when LibJulia.jl_is_uint64(ans)
        return LibJulia.jl_unbox_uint64(ans)
      when LibJulia.jl_is_float32(ans)
        return LibJulia.jl_unbox_float32(ans)
      when LibJulia.jl_is_float64(ans)
        return LibJulia.jl_unbox_float64(ans)
      else
        nil
      end
    end
  end
end
