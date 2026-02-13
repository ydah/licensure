# frozen_string_literal: true

RSpec.describe Licensure::DependencyResolver do
  let(:fixture_lockfile) { File.expand_path("../fixtures/Gemfile.lock.sample", __dir__) }

  describe "#resolve" do
    it "returns only direct dependencies by default" do
      result = described_class.new(lockfile_path: fixture_lockfile).resolve

      expect(result).to eq([
        { name: "rake", version: "13.2.1" },
        { name: "rspec", version: "3.13.0" }
      ])
    end

    it "includes transitive dependencies with recursive option" do
      result = described_class.new(lockfile_path: fixture_lockfile, recursive: true).resolve
      names = result.map { |dependency| dependency[:name] }

      expect(names).to include("diff-lcs", "rspec-core", "rspec-support")
      expect(names).not_to include("bundler")
    end

    it "raises when lockfile does not exist" do
      resolver = described_class.new(lockfile_path: "missing.lock")

      expect { resolver.resolve }
        .to raise_error(Licensure::DependencyResolutionError, /Gemfile.lock not found/)
    end

    it "always excludes bundler" do
      result = described_class.new(lockfile_path: fixture_lockfile, recursive: true).resolve

      expect(result.map { |dependency| dependency[:name] }).not_to include("bundler")
    end
  end
end
