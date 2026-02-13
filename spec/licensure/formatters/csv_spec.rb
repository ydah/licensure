# frozen_string_literal: true

require "csv"

RSpec.describe Licensure::Formatters::Csv do
  let(:output) { StringIO.new }
  subject(:formatter) { described_class.new(output: output) }

  let(:gem_info) do
    Licensure::GemLicenseInfo.new(
      name: "rails",
      version: "7.1.0",
      licenses: ["MIT"],
      source: :gemspec,
      homepage: "https://rubyonrails.org"
    )
  end

  it "renders list output" do
    formatter.render([gem_info])

    rows = CSV.parse(output.string)
    expect(rows.first).to eq(%w[Gem Version License Source Homepage])
    expect(rows[1]).to eq(["rails", "7.1.0", "MIT", "gemspec", "https://rubyonrails.org"])
  end

  it "renders check output" do
    result = Licensure::CheckResult.new(
      passed: [gem_info],
      violations: [Licensure::Violation.new(gem_info: gem_info, reason: "not allowed")],
      warnings: []
    )

    formatter.render_check_result(result)

    rows = CSV.parse(output.string)
    expect(rows.first).to eq(%w[Gem Version License Source Status Reason])
    expect(rows.map { |row| row[4] }).to include("PASSED", "VIOLATION")
  end

  it "writes to IO" do
    formatter.render([])

    expect(output.string).not_to be_empty
  end
end
