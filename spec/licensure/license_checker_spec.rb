# frozen_string_literal: true

RSpec.describe Licensure::LicenseChecker do
  let(:configuration) do
    Licensure::Configuration.new(
      "allowed_licenses" => ["MIT", "Apache-2.0"],
      "ignored_gems" => ["ignored-gem"],
      "deny_unknown" => true
    )
  end

  subject(:checker) { described_class.new(configuration: configuration) }

  it "passes gems with allowed licenses" do
    gem_info = Licensure::GemLicenseInfo.new(name: "rails", version: "1.0", licenses: ["MIT"], source: :api, homepage: nil)

    result = checker.check([gem_info])

    expect(result.passed).to eq([gem_info])
    expect(result.violations).to be_empty
    expect(result.warnings).to be_empty
  end

  it "flags gems with disallowed licenses" do
    gem_info = Licensure::GemLicenseInfo.new(name: "copyleft", version: "1.0", licenses: ["GPL-3.0"], source: :api, homepage: nil)

    result = checker.check([gem_info])

    expect(result.violations.size).to eq(1)
    expect(result.violations.first.reason).to include("not in the allowed list")
  end

  it "adds warning for unknown licenses when deny_unknown is true" do
    gem_info = Licensure::GemLicenseInfo.new(name: "unknown", version: "1.0", licenses: [], source: :unknown, homepage: nil)

    result = checker.check([gem_info])

    expect(result.warnings.size).to eq(1)
    expect(result.warnings.first.reason).to eq("License not specified")
  end

  it "passes unknown licenses when deny_unknown is false" do
    config = Licensure::Configuration.new(
      "allowed_licenses" => ["MIT"],
      "ignored_gems" => [],
      "deny_unknown" => false
    )
    checker = described_class.new(configuration: config)
    gem_info = Licensure::GemLicenseInfo.new(name: "unknown", version: "1.0", licenses: [], source: :unknown, homepage: nil)

    result = checker.check([gem_info])

    expect(result.passed).to eq([gem_info])
    expect(result.warnings).to be_empty
  end

  it "ignores configured gems" do
    ignored = Licensure::GemLicenseInfo.new(name: "ignored-gem", version: "1.0", licenses: ["GPL-3.0"], source: :api, homepage: nil)

    result = checker.check([ignored])

    expect(result.passed).to be_empty
    expect(result.violations).to be_empty
    expect(result.warnings).to be_empty
  end

  it "skips allow-list check when allowed_licenses is empty" do
    config = Licensure::Configuration.new(
      "allowed_licenses" => [],
      "ignored_gems" => [],
      "deny_unknown" => true
    )
    checker = described_class.new(configuration: config)
    gem_info = Licensure::GemLicenseInfo.new(name: "copyleft", version: "1.0", licenses: ["GPL-3.0"], source: :api, homepage: nil)

    result = checker.check([gem_info])

    expect(result.passed).to eq([gem_info])
    expect(result.violations).to be_empty
  end

  it "passes when one of multiple licenses is allowed" do
    gem_info = Licensure::GemLicenseInfo.new(
      name: "dual-license",
      version: "1.0",
      licenses: ["GPL-3.0", "MIT"],
      source: :api,
      homepage: nil
    )

    result = checker.check([gem_info])

    expect(result.passed).to eq([gem_info])
    expect(result.violations).to be_empty
  end
end
