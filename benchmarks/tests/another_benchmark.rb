Awfy.group "Testing Awfy - example with iteration" do
  report "#each vs for" do
    array = [1, 2, 3, 4, 5] * 1000

    control "Array#each" do
      v = 0
      array.each do |i|
        v = i * 2
      end
      v
    end

    test "for" do
      v = 0
      for i in array
        v = i * 2
      end
      v
    end
  end
end
