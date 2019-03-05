require "spec_helper"

RSpec.describe "Julia object conversion" do
  specify 'function' do
    func = Julia.eval("x -> x^2 + 2x + 1")
    expect(func.class).to eq(Julia::Function)
  end
end
