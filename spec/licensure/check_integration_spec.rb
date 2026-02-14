# frozen_string_literal: true

RSpec.describe "license normalization in check flow" do
  it "does not add violations when BSD 2-Clause is allowed as BSD-2-Clause" do
    gem_name = "sample-gem"
    version = "1.0.0"

    allow(Gem::Specification).to receive(:find_by_name).with(gem_name).and_raise(Gem::LoadError)
    stub_request(:get, "https://rubygems.org/api/v1/gems/#{gem_name}.json")
      .with(headers: { "User-Agent" => "Licensure/#{Licensure::VERSION}" })
      .to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: {
          licenses: ["BSD 2-Clause"],
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
            key: "bsd-2-clause",
            name: "BSD 2-Clause \"Simplified\" License",
            spdx_id: "BSD-2-Clause"
          }
        }.to_json
      )

    fetched = Licensure::LicenseFetcher.new.fetch(gem_name, version)
    configuration = Licensure::Configuration.new(
      "allowed_licenses" => ["BSD-2-Clause"],
      "ignored_gems" => [],
      "deny_unknown" => true
    )

    result = Licensure::LicenseChecker.new(configuration: configuration).check([fetched])

    expect(result.violations).to be_empty
    expect(result.passed).to eq([fetched])
  end
end
