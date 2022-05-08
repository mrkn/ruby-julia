RubyRange(b::B, s, e::E, excl::Bool = false) where {B<:Real,E<:Real} =
  RubyRange(Base.convert(promote_type(B,E), b), s, Base.convert(promote_type(B,E), e), excl)

RubyRange(b::T, s::AbstractFloat, e::T, excl::Bool = false) where {T<:Real} = RubyRange(promote(b, s, e)..., excl)
RubyRange(b::T, s::AbstractFloat, e::T, excl::Bool = false) where {T<:AbstractFloat} = RubyRange(promote(b, s, e)..., excl)
RubyRange(b::T, s::Real, e::T, excl::Bool = false) where {T<:AbstractFloat} = RubyRange(promote(b, s, e)..., excl)

RubyRange(b::T, s::T, e::T, excl::Bool = false) where {T<:AbstractFloat} = make_range(b, s, e, excl)
RubyRange(b::T, s::T, e::T, excl::Bool = false) where {T<:Real} = make_range(b, s, e, excl)

function make_range(start::T, step::T, stop::T, excl::Bool) where T
  if excl
    return start:step:stop
  else
    return start:step:(stop + one(stop))
  end
end

function make_range(start::T, step::T, stop::T, excl::Bool) where {T<:Union{Float16,Float32,Float64}}
  step == 0 && throw(ArgumentError("range step cannot be zero"))
  step_n, step_d = Base.rat(step)
  if step_d != 0 && T(step_n / step_d) == step
    start_n, start_d = Base.rat(start)
    stop_n, stop_d = Base.rat(stop)
    if start_d != 0 && stop_d != 0 && T(start_n/start_d) == start && T(stop_n/stop_d) == stop
      den = Base.lcm_unchecked(start_d, step_d)  # use same denominator for start and step
      m = maxintfloat(T, Int)
      if den != 0 && abs(start*den) <= m && abs(step*den) <= m &&  # will round succeed?
           rem(den, start_d) == 0 && rem(den, step_d) == 0         # check lcm overflow
        start_n = round(Int, start*den)
        step_n = round(Int, step*den)
        len = max(0, div(den*stop_n - stop_d*start_n + step_n*stop_d, step_n*stop_d))
        # Integer ops could overflow, so check that this makes sense
        if Base.isbetween(start, start + (len-1)*step, stop + step/2) &&
             !Base.isbetween(start, start + len*step, stop)
          if excl
            return StepRangeLen(start, step, len-1)
          else
            return StepRangeLen(start, step, len)
          end
        end
      end
    end
  end
  # Fallback, taking start and step literally
  lf = (stop - start) / step
  if lf < 0
    len = 0
  elseif lf == 0
    len = 1
  else
    len = round(Int, lf) + 1
    stop′ = start+ (len - 1)*step
    # if we've overshoot the end, subtract one:
    len -= (start < stop < stop′) + (start > stop > stop′)
    if !excl
      len += 1
    end
  end
  return StepRangeLen(start, step, len)
end
