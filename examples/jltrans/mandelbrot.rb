require_relative "jltrans"

extend JLTrans

show_jl = ARGV.include?("--show-jl")

def abs2(z)
  z.real * z.real + z.imag * z.imag
end

def mandel(z)
  c = z
  maxiter = 80
  (1 ... maxiter).each do |n|
    return n - 1 if abs2(z) > 4
    z = z**2 + c
  end
  maxiter
end

def mandelbrot
  ary = []
  (-1 .. 1.0).step(0.1) do |i|
    (-2 .. 0.5).step(0.1) do |r|
      ary << mandel(Complex(r, i))
    end
  end
  ary
end

alias mandelbrot_rb mandelbrot

jl_trans method(:mandelbrot)

if show_jl
  puts code_julia(:mandelbrot)
end

### TEST

rb = mandelbrot_rb
jl = mandelbrot

unless rb == jl
  if rb.length != jl.length
    $stderr.puts "CHECK FAILED: length mismatched between mandelbrot_rb and mandelbrot"
  else
    rb.zip(jl).each_with_index do |(a, b), i|
      if a != b
        $stderr.puts "- MISMATCH at #{i}: #{a} != #{b}"
      end
    end
  end
  abort
end

### BENCHMARK

require "enumerable/statistics"

def timeit(min_trials: 5, min_time: 2000.0)
  ts = []
  total_time = 0.0
  i = 0
  while i < min_trials || total_time < min_time
    t0 = Time.now
    yield
    e = 1000 * (Time.now - t0)
    total_time += e
    ts << e if i > 0
    i += 1
  end
  [ts.min, ts.max, ts.mean, ts.stdev]
end

puts "         name,   min,   max,  mean,   std"
puts "mandelbrot_rb,%6.3f,%6.3f,%6.3f,%6.3f" % timeit { mandelbrot_rb }
puts "mandelbrot_jl,%6.3f,%6.3f,%6.3f,%6.3f" % timeit { mandelbrot }
