Awfy.group "iteration" do
  report "#each vs for" do
    array = [1, 2, 3, 4, 5] * 1000
    array_size = array.size

    control "Array#each" do
      v = 0
      array.each do |i|
        v = i * 2
      end
      v
    end

    alternative "while" do
      v = 0
      i = 0
      while i < array_size
        v = array[i] * 2
        i += 1
      end
      v
    end

    test "for" do
      v = 0
      for i in array # rubocop:disable Style/For
        v = i * 2
      end
      v
    end
  end
end
