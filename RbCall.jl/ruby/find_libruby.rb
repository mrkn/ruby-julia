require "pathname"
require "rbconfig"

@windows_p = false
@apple_p = false

case RUBY_PLATFORM
when /mswin/, /mingw/
  @windows_p = true
when /darwin/
  @apple_p = true
end

@DLEXT = RbConfig::CONFIG["DLEXT"]
@DLEXT = if @DLEXT
           ".#{@DLEXT}"
         elsif @windows_p
           ".dll"
         elsif @apple_p
           ".dylib"
         else
           ".so"
         end

def linked_libruby
  # TODO
  nil
end

def each_candidate_names(ext: @DLEXT)
  return enum_for(__method__) unless block_given?

  yield RbConfig::CONFIG["LIBRUBY"] if RbConfig::CONFIG["LIBRUBY"]

  dlprefix = @windows_p ? "" : "lib"

  [
    "ruby%s" % RUBY_VERSION,
    "ruby%s" % RUBY_VERSION.split(".")[0],
    "ruby"
  ].each do |stem|
    yield "#{dlprefix}#{stem}#{ext}"
  end
end

def each_candidate_path(&block)
  return enum_for(__method__) unless block_given?

  yield linked_libruby

  lib_dirs = []
  lib_dirs << RbConfig::CONFIG["libdir"]

  if @windows_p
    lib_dirs << File.dirname(RbConfig.ruby)
  else
    lib_dirs << File.join(File.dirname(File.dirname(RbConfig.ruby)), "lib")
  end

  lib_dirs << RbConfig::CONFIG["exec_prefix"]
  lib_dirs << File.join(RbConfig::CONFIG["exec_prefix"], "lib")

  lib_basenames = each_candidate_names.to_a

  candidates = []
  lib_dirs.each do |dir|
    lib_basenames.each do |basename|
      fullname = Pathname(File.join(dir, basename))
      candidates << fullname unless candidates.include?(fullname)
    end
  end

  candidates.each(&block)
end

def remove_apple_suffix(path)
  s = path.to_s
  s.delete_suffix!(".dylib")
  s.delete_suffix!(".so")
  Pathname(s)
end

def normalize_path(path, ext: @DLEXT, apple_p: @apple_p)
  return nil unless path
  return nil unless path.absolute?
  return path.realpath if path.exist?
  path_with_ext = Pathname("#{path}#{ext}")
  return path_with_ext.realpath if path_with_ext.exist?
  return normalize_path(remove_apple_suffix(path), ext: ".so", apple_p: false) if apple_p
  nil
end

def each_candidate_libruby
  return enum_for(__method__) unless block_given?

  each_candidate_path do |path|
    normalized = normalize_path(path)
    yield normalized if normalized
  end
end

def find_libruby
  each_candidate_libruby.first
end

print find_libruby
