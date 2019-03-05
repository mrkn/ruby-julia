require "spec_helper"

RSpec.describe "Julia object wrapper" do
  specify do
    func = Julia.eval("x -> x^2 + 2x + 1")
    expect(func).to be_kind_of(Julia::ObjectWrapper)
  end
end
