# frozen_string_literal: true

require_relative "lib/awfy/version"

Gem::Specification.new do |spec|
  spec.name = "awfy"
  spec.version = Awfy::VERSION
  spec.authors = ["Stephen Ierodiaconou"]
  spec.email = ["stevegeek@gmail.com"]

  spec.summary = "awfy (Are We Fast Yet?) a Benchmarking tool"
  spec.description = "awfy is a benchmarking tool that allows you to define groups of benchmarks and compare against runtimes, branches etc."
  spec.homepage = "https://github.com/stevegeek/awfy"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  # spec.metadata["changelog_uri"] = ""

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  spec.add_dependency "thor", ">= 1.3", "< 2.0"
  spec.add_dependency "git", ">= 2.3", "< 3.0"
  spec.add_dependency "terminal-table", ">= 3.0", "< 4.0"
  spec.add_dependency "benchmark-ips", ">= 2.14", "< 3.0"
  spec.add_dependency "memory_profiler", ">= 1.1", "< 2.0"
  spec.add_dependency "singed", ">= 0.2", "< 1.0"
  spec.add_dependency "stackprof", ">= 0.2", "< 1.0"
end
