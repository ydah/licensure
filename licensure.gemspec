# frozen_string_literal: true

require_relative "lib/licensure/version"

Gem::Specification.new do |spec|
  spec.name = "licensure"
  spec.version = Licensure::VERSION
  spec.authors = ["Yudai Takada"]
  spec.email = ["t.yudai92@gmail.com"]

  spec.summary = "License compliance checker for Ruby dependencies"
  spec.description = "Licensure collects dependency license metadata and validates it against a configurable allow list."
  spec.homepage = "https://github.com/ydah/licensure"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/releases"

  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |file|
      (file == gemspec) ||
        file.start_with?(*%w[bin/ Gemfile .gitignore .rspec spec/ .github/ .idea/])
    end
  end

  spec.bindir = "exe"
  spec.executables = ["licensure"]
  spec.require_paths = ["lib"]

  spec.add_dependency "bundler", ">= 2.0"
  spec.add_dependency "csv", ">= 3.0"
end
