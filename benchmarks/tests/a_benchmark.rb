Awfy.group "Numerics" do
  report "#+" do
    big_decimal_1 = BigDecimal("1.0")
    big_decimal_2 = BigDecimal("2.0")
    integer_1 = 1
    integer_2 = 2
    float_1 = 1.0
    float_2 = 2.0
    rational_1 = Rational(1, 1)
    rational_2 = Rational(2, 1)
    complex_1 = Complex(1, 1)
    complex_2 = Complex(2, 2)

    control "BigDecimal" do
      big_decimal_1 + big_decimal_2
    end

    control "Integer" do
      integer_1 + integer_2
    end

    control "Float" do
      float_1 + float_2
    end

    control "Rational" do
      rational_1 + rational_2
    end

    assert(
      memory: {total_allocated_memory: {eq: 0.0}},
      ips: {within: {times: 2.0, of: "Rational"}}
    )
    test "Complex" do
      complex_1 + complex_2
    end
  end

  report "#*" do
    big_decimal_1 = BigDecimal("1.0")
    big_decimal_2 = BigDecimal("2.0")
    integer_1 = 1
    integer_2 = 2
    float_1 = 1.0
    float_2 = 2.0
    rational_1 = Rational(1, 1)
    rational_2 = Rational(2, 1)
    complex_1 = Complex(1, 1)
    complex_2 = Complex(2, 2)

    control "BigDecimal" do
      big_decimal_1 * big_decimal_2
    end

    control "Integer" do
      integer_1 * integer_2
    end

    control "Float" do
      float_1 * float_2
    end

    control "Rational" do
      rational_1 * rational_2
    end

    test "Complex" do
      complex_1 * complex_2
    end
  end
end
