# frozen_string_literal: true

Awfy.group "Short Sleep Test" do
  report "Random Sleep" do
    test "Short Sleep" do
      sleep rand(0.1..0.5)
    end
  end
end

Awfy.group "Medium Sleep Test" do
  report "Random Sleep" do
    test "Medium Sleep" do
      sleep rand(0.5..1.5)
    end
  end
end

Awfy.group "Long Sleep Test" do
  report "Random Sleep" do
    test "Long Sleep" do
      sleep rand(1.5..2.5)
    end
  end
end

Awfy.group "Variable Sleep Test" do
  report "Random Sleep" do
    test "Variable Sleep" do
      sleep rand(0.1..3.0)
    end
  end
end

Awfy.group "Shallow Sleep Test" do
  report "Random Sleep" do
    test "Shallow Sleep" do
      sleep rand(0.2..0.8)
    end
  end
end

Awfy.group "Deep Sleep Test" do
  report "Random Sleep" do
    test "Deep Sleep" do
      sleep rand(1.0..2.0)
    end
  end
end

Awfy.group "Dream State Test" do
  report "Random Sleep" do
    test "Dream State" do
      sleep rand(2.0..3.0)
    end
  end
end

Awfy.group "Power Nap Test" do
  report "Random Sleep" do
    test "Power Nap" do
      sleep rand(0.1..0.3)
    end
  end
end
