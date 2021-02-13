require 'julia/error'
require 'fiddle'

module Julia
  module LibJulia
    module Finder
      case RUBY_PLATFORM
      when /cygwin/
        libprefix = 'cyg'
        libsuffix = 'dll'
      when /mingw/, /mswin/
        libprefix = ''
        libsuffix = 'dll'
      when /darwin/
        libsuffix = 'dylib'
      end

      LIBPREFIX = libprefix || 'lib'
      LIBSUFFIX = libsuffix || 'so'

      class << self
        DEFAULT_JULIA = -'julia'

        def find_libjulia(julia = nil)
          debug_report "find_libjulia(#{julia.inspect})"
          _, julia_config = investigate_julia(julia)

          libpath = File.join(julia_config[:libdir], "libjulia.#{LIBSUFFIX}")
          if File.file? libpath
            begin
              return dlopen(libpath)
            rescue Fiddle::DLError
              debug_report "#{$!.class}: #{$!.message}"
            else
              debug_report "Success to dlopen #{fullname}"
            end
          else
            debug_report "Unable to find #{fullname}"
          end

          raise Julia::JuliaNotFound
        end

        def investigate_julia(julia = nil)
          julia ||= DEFAULT_JULIA
          Array(julia).each do |julia_cmd|
            julia_config = run_julia_investigator(julia_cmd)
            return [julia_cmd, julia_config] unless julia_config.empty?
          end
        rescue
          debug_report "investigate_julia: (#{$!.class}) #{$!.message}"
          raise Julia::JuliaNotFound
        else
          raise Julia::JuliaNotFound
        end

        def run_julia_investigator(julia_cmd)
          debug_report "run_julia_investigator(#{julia_cmd})"
          IO.popen({}, [julia_cmd, julia_investigator_jl], 'r') do |io|
            {}.tap do |config|
              io.each_line do |line|
                next unless line =~ /: /
                key, value = line.chomp.split(': ', 2)
                case value
                when 'true', 'false'
                  value = (value == 'true')
                end
                config[key.to_sym] = value if value != 'nothing'
              end
            end
          end
        rescue Errno::ENOENT
          raise Julia::JuliaNotFound
        end

        def julia_investigator_jl
          File.expand_path('../investigator.jl', __FILE__)
        end

        private

        def dlopen(path)
          # NOTE: libjulia needs to be dlopened with RTLD_GLOBAL.
          # Fiddle.dlopen(path) is same as Fiddle::Handle.new(path),
          # and Fiddle::Handle.new defaultly specifies RTLD_GLOBAL.
          Fiddle.dlopen(path).tap do |handle|
            debug_report "dlopen(#{path.inspect}) = #{handle.inspect}" if handle
          end
        end

        def debug_report(message)
          return unless debug?
          $stderr.puts "DEBUG(find_libjulia) #{message}"
        end

        def debug?
          @debug_p ||= (ENV['RUBY_JULIA_DEBUG_FIND_LIBJULIA'] == '1')
        end
      end
    end
  end
end
