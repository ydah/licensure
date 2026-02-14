# frozen_string_literal: true

RSpec.describe Licensure::LicenseFetcher do
  subject(:fetcher) { described_class.new }

  describe "#fetch" do
    let(:gem_name) { "sample-gem" }
    let(:version) { "1.0.0" }

    it "uses local gemspec when available" do
      spec = instance_double(
        Gem::Specification,
        licenses: ["MIT"],
        license: nil,
        homepage: "https://example.test",
        metadata: {}
      )
      allow(Gem::Specification).to receive(:find_by_name).with(gem_name).and_return(spec)

      result = fetcher.fetch(gem_name, version)

      expect(result.licenses).to eq(["MIT"])
      expect(result.source).to eq(:gemspec)
      expect(result.homepage).to eq("https://example.test")
    end

    it "falls back to RubyGems API when gemspec is unavailable" do
      allow(Gem::Specification).to receive(:find_by_name).with(gem_name).and_raise(Gem::LoadError)
      stub_request(:get, "https://rubygems.org/api/v1/gems/#{gem_name}.json")
        .with(headers: { "User-Agent" => "Licensure/#{Licensure::VERSION}" })
        .to_return(
          status: 200,
          headers: { "Content-Type" => "application/json" },
          body: {
            licenses: ["Apache-2.0"],
            homepage_uri: "https://rubygems.org/gems/sample-gem"
          }.to_json
        )

      result = fetcher.fetch(gem_name, version)

      expect(result.licenses).to eq(["Apache-2.0"])
      expect(result.source).to eq(:api)
      expect(result.homepage).to eq("https://rubygems.org/gems/sample-gem")
    end

    it "normalizes non-SPDX labels with GitHub repository license metadata" do
      allow(Gem::Specification).to receive(:find_by_name).with(gem_name).and_raise(Gem::LoadError)
      stub_request(:get, "https://rubygems.org/api/v1/gems/#{gem_name}.json")
        .with(headers: { "User-Agent" => "Licensure/#{Licensure::VERSION}" })
        .to_return(
          status: 200,
          headers: { "Content-Type" => "application/json" },
          body: {
            licenses: ["Apache License, Version 2.0"],
            homepage_uri: "https://rubygems.org/gems/sample-gem",
            source_code_uri: "https://github.com/example/sample-gem"
          }.to_json
        )

      stub_request(:get, "https://api.github.com/repos/example/sample-gem/license")
        .with(
          headers: {
            "Accept" => "application/vnd.github+json",
            "User-Agent" => "Licensure/#{Licensure::VERSION}",
            "X-GitHub-Api-Version" => "2022-11-28"
          }
        )
        .to_return(
          status: 200,
          headers: { "Content-Type" => "application/json" },
          body: {
            license: {
              key: "apache-2.0",
              name: "Apache License 2.0",
              spdx_id: "Apache-2.0"
            }
          }.to_json
        )

      result = fetcher.fetch(gem_name, version)

      expect(result.licenses).to eq(["Apache-2.0"])
      expect(result.source).to eq(:api)
      expect(result.homepage).to eq("https://rubygems.org/gems/sample-gem")
    end

    it "returns unknown when API times out" do
      allow(Gem::Specification).to receive(:find_by_name).with(gem_name).and_raise(Gem::LoadError)
      stub_request(:get, "https://rubygems.org/api/v1/gems/#{gem_name}.json").to_timeout

      result = fetcher.fetch(gem_name, version)

      expect(result.licenses).to eq([])
      expect(result.source).to eq(:unknown)
    end

    it "returns unknown when both sources fail" do
      allow(Gem::Specification).to receive(:find_by_name).with(gem_name).and_raise(Gem::LoadError)
      stub_request(:get, "https://rubygems.org/api/v1/gems/#{gem_name}.json").to_return(status: 404)

      result = fetcher.fetch(gem_name, version)

      expect(result.licenses).to eq([])
      expect(result.source).to eq(:unknown)
    end
  end

  describe "#fetch_all" do
    it "fetches all dependencies in order" do
      allow(fetcher).to receive(:fetch).with("a", "1.0").and_return(:a)
      allow(fetcher).to receive(:fetch).with("b", "2.0").and_return(:b)

      result = fetcher.fetch_all([
        { name: "a", version: "1.0" },
        { name: "b", version: "2.0" }
      ])

      expect(result).to eq([:a, :b])
    end
  end
end
