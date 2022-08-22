class TestJulia < Test::Unit::TestCase
  test("Julia::VERSION") do
    assert(defined?(Julia::VERSION))
  end

  sub_test_case("Julia.eval") do
    data(
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
      '[1, 2, 3]' => [[1, 2, 3], "Vector{Any}([1, 2, 3])"]
    )
    def test_by_equal(data)
      expected, source = data
      assert_equal(expected, Julia.eval(source))
    end
  end
end
