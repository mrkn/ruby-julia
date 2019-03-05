require "spec_helper"

RSpec.describe "Julia object conversion" do
  specify 'function' do
    func = Julia.eval("x -> x^2 + 2x + 1")
    p func.__typeof_str__
    expect(func.(5)).to eq(36)
    expect(func.(5).class).to eq(Integer)
    expect(func.(5.0).class).to eq(Float)
  end
end
