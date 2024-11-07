# Awfy (Are We Fast Yet)

CLI tool to help run suites of benchmarks and compare results between control implementations, across branches and with or without YJIT.

The benchmarks are written using a simple DSL in your target project.

Supports running:

- IPS benchmarks (with [benchmark-ips](https://rubygems.org/gems/benchmark-ips))
- Memory profiling (with [memory_profiler](https://rubygems.org/gems/memory_profiler))
- CPU profiling (with [stackprof](https://rubygems.org/gems/stackprof))
- Flamegraph profiling (with [singed](https://rubygems.org/gems/singed))

Awfy can also create summary reports of the results which can be useful for comparing the performance of different implementations **(supported for IPS and memory benchmarks)**.

### Example Report:

```
+---------------------------------------------------------------------------+
|                           Struct/#some_method                             |
+--------+---------+----------------------------+-------------+-------------+
| Branch | Runtime | Name                       | IPS         | Vs baseline |
+--------+---------+----------------------------+-------------+-------------+
| perf   | mri     |                 Ruby Struct|      3.288M |      2.26 x |
| perf   | yjit    |                 Ruby Struct|      3.238M |      2.22 x |
| perf   | yjit    |                    MyStruct|      2.364M |      1.62 x |
| main   | yjit    |                    MyStruct|      2.255M |      1.55 x |
| perf   | mri     |         (baseline) MyStruct|      1.455M |      -      |
+--------+---------+----------------------------+-------------+-------------+
| main   | mri     |                    MyStruct|      1.248M |      -1.1 x |
| perf   | yjit    |                 Dry::Struct|      1.213M |      -1.2 x |
| perf   | mri     |                 Dry::Struct|    639.178k |     -2.28 x |
| perf   | yjit    |     ActiveModel::Attributes|    487.398k |     -2.99 x |
| perf   | mri     |     ActiveModel::Attributes|    310.554k |     -4.69 x |
+--------+---------+----------------------------+-------------+-------------+
```

## Installation

Add the gem to your application:

```ruby
group :development, :test do
  gem "awfy", require: false
end
```

If bundler is not being used to manage dependencies, install the gem by executing:

```bash
gem install awfy
```

## Usage

Imagine we have a custom implementation of a Struct class called `MyStruct`. We want to compare the performance of our implementation with the built-in `Struct` class
and other similar implementations.

First, we need to create a setup file in the `benchmarks/setup.rb` directory. For example:

```ruby
# setup.rb

# We need to require Awfy to use the DSL in our tests
require "awfy"

require "dry-struct"
require "active_model"

class DryStruct < Dry::Struct
  attribute :name, Types::String
  attribute :age, Types::Integer
end

class ActiveModelAttributes
  include ActiveModel::API
  include ActiveModel::Attributes
  
  attribute :name, :string
  attribute :age, :integer
end

# ... etc
```

Then we write benchmarks in files in the `benchmarks/tests` directory. For example:

```ruby
# benchmarks/tests/struct.rb

# A group is a collection of related reports
Awfy.group "Struct" do
  # A report is a collection of tests related to one method or feature we want to benchmark
  report "#some_method" do
    # We do not want to the benchmark to include the creation of the object
    my_struct = MyStruct.new(name: "John", age: 30)
    ruby_struct = Struct.new(:name, :age).new("John", 30)
    dry_struct = DryStruct.new(name: "John", age: 30)
    active_model_attributes = ActiveModelAttributes.new(name: "John", age: 30)
    
    # "control" blocks are used to compare the performance to other implementations
    control "Ruby Struct" do
      ruby_struct.some_method
    end
    
    control "Dry::Struct" do
      dry_struct.some_method
    end
    
    control "ActiveModel::Attributes" do
      active_model_attributes.some_method
    end
    
    # This is our implementation under test
    test "MyStruct" do
      my_struct.some_method
    end  
  end
  
end
```

### IPS Benchmarks & Summary Reports

Say you are working on performance improvements in a branch called `perf`.

```bash
git checkout perf

# ... make some changes ... then run the benchmarks

bundle exec awfy ips Struct "#some_method" --compare-with=main --runtime=both
```

Note the comparison here is with the "baseline" which is the "test" block running on MRI without YJIT enabled, on the
current branch.

```
Running IPS for:
> Struct/#some_method...
> [mri - branch 'perf'] Struct / #some_method
> [mri - branch 'main'] Struct / #some_method
> [yjit - branch 'perf'] Struct / #some_method
> [yjit - branch 'main'] Struct / #some_method
+---------------------------------------------------------------------------+
|                           Struct/#some_method                             |
+--------+---------+----------------------------+-------------+-------------+
| Branch | Runtime | Name                       | IPS         | Vs baseline |
+--------+---------+----------------------------+-------------+-------------+
| perf   | mri     |                 Ruby Struct|      3.288M |      2.26 x |
| perf   | yjit    |                 Ruby Struct|      3.238M |      2.22 x |
| perf   | yjit    |                    MyStruct|      2.364M |      1.62 x |
| main   | yjit    |                    MyStruct|      2.255M |      1.55 x |
| perf   | mri     |         (baseline) MyStruct|      1.455M |      -      |
+--------+---------+----------------------------+-------------+-------------+
| main   | mri     |                    MyStruct|      1.248M |      -1.1 x |
| perf   | yjit    |                 Dry::Struct|      1.213M |      -1.2 x |
| perf   | mri     |                 Dry::Struct|    639.178k |     -2.28 x |
| perf   | yjit    |     ActiveModel::Attributes|    487.398k |     -2.99 x |
| perf   | mri     |     ActiveModel::Attributes|    310.554k |     -4.69 x |
+--------+---------+----------------------------+-------------+-------------+
```


### Memory Profiling

```bash
bundle exec awfy memory Struct "#some_method"
```

Produces a report like:

```
+----------------------------------------------------------------------------------------------------------------+
|                                                  Struct/.new                                                   |
+--------+---------+----------------------------+-------------------+-------------+----------------+-------------+
| Branch | Runtime | Name                       | Total Allocations | Vs baseline | Total Retained | Vs baseline |
+--------+---------+----------------------------+-------------------+-------------+----------------+-------------+
| perf   | mri     |    ActiveModel::Attributes |            1.200k |      3.33 x |            640 |           ∞ |
| perf   | yjit    |    ActiveModel::Attributes |            1.200k |      3.33 x |              0 |        same |
| perf   | mri     |                Dry::Struct |               360 |       1.0 x |            160 |           ∞ |
| perf   | mri     | (baseline) Literal::Struct |               360 |           - |              0 |           - |
+--------+---------+----------------------------+-------------------+-------------+----------------+-------------+
| perf   | yjit    |                Dry::Struct |               360 |        same |              0 |        same |
| perf   | yjit    |            Literal::Struct |               360 |        same |              0 |        same |
| perf   | mri     |                Ruby Struct |               200 |     -0.56 x |              0 |        same |
| perf   | mri     |                  Ruby Data |               200 |     -0.56 x |              0 |        same |
| perf   | yjit    |                Ruby Struct |               200 |     -0.56 x |              0 |        same |
| perf   | yjit    |                  Ruby Data |               200 |     -0.56 x |              0 |        same |
+--------+---------+----------------------------+-------------------+-------------+----------------+-------------+
```

## CLI Options

```
bundle exec awfy -h
Commands:
  awfy flamegraph GROUP REPORT TEST     # Run flamegraph profiling
  awfy help [COMMAND]                   # Describe available commands or one specific command
  awfy ips [GROUP] [REPORT] [TEST]      # Run IPS benchmarks
  awfy list [GROUP]                     # List all tests in a group
  awfy memory [GROUP] [REPORT] [TEST]   # Run memory profiling
  awfy profile [GROUP] [REPORT] [TEST]  # Run CPU profiling

Options:
  [--runtime=RUNTIME]                                                    # Run with and/or without YJIT enabled
                                                                         # Default: both
                                                                         # Possible values: both, yjit, mri
  [--compare-with=COMPARE_WITH]                                          # Name of branch to compare with results on current branch
  [--compare-control], [--no-compare-control], [--skip-compare-control]  # When comparing branches, also re-run all control blocks too
                                                                         # Default: false
  [--summary], [--no-summary], [--skip-summary]                          # Generate a summary of the results
                                                                         # Default: true
  [--verbose], [--no-verbose], [--skip-verbose]                          # Verbose output
                                                                         # Default: false
  [--ips-warmup=N]                                                       # Number of seconds to warmup the benchmark
                                                                         # Default: 1
  [--ips-time=N]                                                         # Number of seconds to run the benchmark
                                                                         # Default: 3
  [--temp-output-directory=TEMP_OUTPUT_DIRECTORY]                        # Directory to store temporary output files
                                                                         # Default: ./benchmarks/tmp
  [--setup-file-path=SETUP_FILE_PATH]                                    # Path to the setup file
                                                                         # Default: ./benchmarks/setup
  [--tests-path=TESTS_PATH]                                              # Path to the tests files
                                                                         # Default: ./benchmarks/tests
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/stevegeek/awfy.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
