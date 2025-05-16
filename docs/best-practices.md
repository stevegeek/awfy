# Best Practices Guide

This guide provides tips and best practices for writing effective benchmarks with Awfy.

## Writing Good Benchmarks

### 1. Isolate What You're Testing

✅ Good:
```ruby
report "#parse" do
  json_string = '{"name":"test"}'  # Setup outside
  
  test "Parser" do
    JSON.parse(json_string)        # Only test parsing
  end
end
```

❌ Bad:
```ruby
report "#parse" do
  test "Parser" do
    json_string = '{"name":"test"}' # Setup inside
    JSON.parse(json_string)         # Tests string creation too
  end
end
```

### 2. Use Realistic Data

✅ Good:
```ruby
report "#process" do
  data = File.read("spec/fixtures/real_world_sample.json")
  test "Processor" do
    process_data(data)
  end
end
```

❌ Bad:
```ruby
report "#process" do
  data = "{}" # Too simple
  test "Processor" do
    process_data(data)
  end
end
```

### 3. Consistent State

✅ Good:
```ruby
report "#modify" do
  original_data = DATA.dup  # Fresh copy each time
  test "Modifier" do
    modify_data(original_data)
  end
end
```

❌ Bad:
```ruby
report "#modify" do
  test "Modifier" do
    modify_data(DATA)  # Modifies shared data
  end
end
```

## Organizing Benchmarks

### 1. Logical Grouping

✅ Good:
```ruby
Awfy.group "String Operations" do
  report "#concat"
  report "#interpolate"
  report "#gsub"
end

Awfy.group "Array Operations" do
  report "#map"
  report "#select"
  report "#reduce"
end
```

❌ Bad:
```ruby
Awfy.group "Misc" do
  report "#concat"    # String method
  report "#map"      # Array method
  report "#to_json"  # JSON method
end
```

### 2. Clear Naming

✅ Good:
```ruby
report "#parse_json_with_symbolized_keys" do
  control "JSON.parse (string keys)" do
    JSON.parse(json)
  end
  
  test "JSON.parse (symbol keys)" do
    JSON.parse(json, symbolize_names: true)
  end
end
```

❌ Bad:
```ruby
report "test1" do
  control "old" do
    JSON.parse(json)
  end
  
  test "new" do
    JSON.parse(json, symbolize_names: true)
  end
end
```

## Performance Tips

### 1. Warmup Periods

```ruby
# Configure appropriate warmup
bundle exec awfy ips --test-warmup=2 --test-time=5
```

This ensures the benchmark runs for a set time before measuring performance. This is supported by `ips`.

### 2. Multiple Iterations

The benchmark will execute multiple iterations of the test to get a more accurate result.

This is only used where appropriate, eg `profile`, as `ips` is already designed to run multiple iterations.

```ruby
# Run tests multiple times
bundle exec awfy ips Arrays --test-iterations=1000000
```

## Next Steps

- Review the [Benchmark Suite Guide](benchmark-suite.md) for DSL details
- See [Advanced Usage](advanced-usage.md) for complex scenarios
- Check [Configuration Guide](configuration.md) for all options