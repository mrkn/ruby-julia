class TestJulia < Test::Unit::TestCase
  test("Julia::VERSION") do
    assert(defined?(Julia::VERSION))
  end

  sub_test_case("Julia.eval") do
    data(
      # Nothing
      "nil" => [nil, "nothing"],
      # Boolean
      "true"  => [true, "true"],
      "false" => [false, "false"],
      # Integer
      "1"         => [1, "1"],
      "Int8(1)"   => [1, "Int8(1)"],
      "Int16(1)"  => [1, "Int16(1)"],
      "Int32(1)"  => [1, "Int32(1)"],
      "Int64(1)"  => [1, "Int64(1)"],
      "UInt8(1)"  => [1, "UInt8(1)"],
      "UInt16(1)" => [1, "UInt16(1)"],
      "UInt32(1)" => [1, "UInt32(1)"],
      "UInt64(1)" => [1, "UInt64(1)"],
    )
    def test_by_same(data)
      expected, source = data
      assert_same(expected, Julia.eval(source))
    end

    data(
      # Float
      "Float32(0.5)" => [0.5, "Float32(0.5)"],
      "Float64(0.5)" => [0.5, "Float64(0.5)"],
      # Complex
      "ComplexF32(1.0, -0.5)" => [Complex(1.0, -0.5), "ComplexF32(1.0, -0.5)"],
      "ComplexF64(1.0,  0.5)" => [Complex(1.0,  0.5), "ComplexF64(1.0,  0.5)"],
      # String
      '"julia"' => ["julia", '"julia"'],
      # Array
      'Vector{Any}([1, 2, 3])' => [[1, 2, 3], "Vector{Any}([1, 2, 3])"],
      '[1, 2, 3]' => [[1, 2, 3], "[1, 2, 3]"]
    )
    def test_by_equal(data)
      expected, source = data
      assert_equal(expected, Julia.eval(source))
    end

    sub_test_case "Vector{Float64} object" do
      def test_float64_array
        result = Julia.eval("[1.0, 2.0, 3.0]")
        assert_kind_of(Julia::JuliaBridge::JuliaWrapper, result)
      end
    end
  end

  test("Julia.tuple") do
    assert_equal(Julia.eval("(1, 2, 3)"),
                 Julia.tuple(1, 2, 3))
  end

  test("Julia.typeof") do
    jary = Julia.eval("[1.0, 2.0, 3.0]")
    assert_equal(Julia.eval("Array{Float64, 1}"),
                 Julia.typeof(jary))
  end

  sub_test_case("Julia::Base.zeros") do
    test("1-D result") do
      expected = Julia.eval("[0.0, 0.0, 0.0]")
      assert_equal(expected,
                   Julia::Base.zeros(Julia::Base::Float64, 3))
    end

    test("2-D result with a splatted shape") do
      expected = Julia.eval("[0.0 0.0; 0.0 0.0]")
      assert_equal(expected,
                   Julia::Base.zeros(Julia::Base::Float64, 2, 2))
    end

    test("2-D result with a tuple shape") do
      expected = Julia.eval("[0.0 0.0; 0.0 0.0]")
      shape = Julia.tuple(2, 2)
      assert_equal(expected,
                   Julia::Base.zeros(Julia::Base::Float64, shape))
    end
  end
end
