require "spec_helper"

RSpec.describe Julia::ValuePtr do
  describe 'GC guard reference' do
    specify do
      rbcall_module = Julia.eval("Main.RbCall", raw: true)
      expect(rbcall_module).to be_kind_of(Julia::ValuePtr)
      before_count = rbcall_module.__refcnt__

      GC.disable
      rbcall_other = Julia.eval("Main.RbCall", raw: true)
      expect(rbcall_other).not_to be(rbcall_module)
      after_count = rbcall_module.__refcnt__
      expect(after_count).to eq(before_count + 1)

      GC.enable

      rbcall_other = nil
      GC.start
      after_gc_count = rbcall_module.__refcnt__
      expect(after_gc_count).to eq(before_count)
    end
  end
end
