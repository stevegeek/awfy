Awfy.group "Test" do
  report "Slow" do
    control "baseline" do
      SlowOperations.process_with_delay(5)
    end
    test "variant" do
      SlowOperations.process_with_delay(10)
    end
  end
end
