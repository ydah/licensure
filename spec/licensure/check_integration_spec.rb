# frozen_string_literal: true

RSpec.describe "license normalization in check flow" do
  def run_check(gem_name:, version:, allowed_licenses:)
    fetched = Licensure::LicenseFetcher.new.fetch(gem_name, version)
    configuration = Licensure::Configuration.new(
      "allowed_licenses" => allowed_licenses,
      "ignored_gems" => [],
      "deny_unknown" => true
    )

    Licensure::LicenseChecker.new(configuration: configuration).check([fetched])
  end

  context "when GitHub SPDX metadata can be resolved" do
    it "does not add violations for descriptive BSD labels" do
      gem_name = "dependency-one"
      version = "1.0.0"

      allow(Gem::Specification).to receive(:find_by_name).with(gem_name).and_raise(Gem::LoadError)
      stub_request(:get, "https://rubygems.org/api/v1/gems/#{gem_name}.json")
        .with(headers: { "User-Agent" => "Licensure/#{Licensure::VERSION}" })
        .to_return(
          status: 200,
          headers: { "Content-Type" => "application/json" },
          body: {
            licenses: ["BSD 2-Clause"],
            source_code_uri: "https://github.com/example/dependency-one"
          }.to_json
        )
      stub_request(:get, "https://api.github.com/repos/example/dependency-one/license")
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
              key: "bsd-2-clause",
              name: "BSD 2-Clause \"Simplified\" License",
              spdx_id: "BSD-2-Clause"
            }
          }.to_json
        )

      result = run_check(gem_name: gem_name, version: version, allowed_licenses: ["BSD-2-Clause"])

      expect(result.violations).to be_empty
      expect(result.passed.map(&:name)).to eq([gem_name])
    end
  end

  context "when GitHub metadata is not available" do
    it "does not add violations for descriptive Apache labels" do
      gem_name = "dependency-two"
      version = "1.1.0"

      allow(Gem::Specification).to receive(:find_by_name).with(gem_name).and_raise(Gem::LoadError)
      stub_request(:get, "https://rubygems.org/api/v1/gems/#{gem_name}.json")
        .with(headers: { "User-Agent" => "Licensure/#{Licensure::VERSION}" })
        .to_return(
          status: 200,
          headers: { "Content-Type" => "application/json" },
          body: {
            licenses: ["Apache License, Version 2.0"],
            homepage_uri: "https://packages.example/dependency-two"
          }.to_json
        )

      result = run_check(gem_name: gem_name, version: version, allowed_licenses: ["Apache-2.0"])

      expect(result.violations).to be_empty
      expect(result.passed.map(&:name)).to eq([gem_name])
    end

    it "does not add violations when GitHub lookup returns 404" do
      gem_name = "dependency-three"
      version = "2.0.0"

      allow(Gem::Specification).to receive(:find_by_name).with(gem_name).and_raise(Gem::LoadError)
      stub_request(:get, "https://rubygems.org/api/v1/gems/#{gem_name}.json")
        .with(headers: { "User-Agent" => "Licensure/#{Licensure::VERSION}" })
        .to_return(
          status: 200,
          headers: { "Content-Type" => "application/json" },
          body: {
            licenses: ["Apache 2.0"],
            homepage_uri: "https://github.com/example/dependency-three"
          }.to_json
        )
      stub_request(:get, "https://api.github.com/repos/example/dependency-three/license")
        .with(
          headers: {
            "Accept" => "application/vnd.github+json",
            "User-Agent" => "Licensure/#{Licensure::VERSION}",
            "X-GitHub-Api-Version" => "2022-11-28"
          }
        )
        .to_return(status: 404)

      result = run_check(gem_name: gem_name, version: version, allowed_licenses: ["Apache-2.0"])

      expect(result.violations).to be_empty
      expect(result.passed.map(&:name)).to eq([gem_name])
    end
  end
end
