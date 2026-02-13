# frozen_string_literal: true

require "json"

RSpec.describe Licensure::Formatters::Json do
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

    payload = JSON.parse(output.string)
    expect(payload["generated_at"]).not_to be_nil
    expect(payload["gems"].size).to eq(1)
    expect(payload["gems"][0]["name"]).to eq("rails")
  end

  it "renders check output" do
    result = Licensure::CheckResult.new(
      passed: [gem_info],
      violations: [Licensure::Violation.new(gem_info: gem_info, reason: "not allowed")],
      warnings: []
    )

    formatter.render_check_result(result)

    payload = JSON.parse(output.string)
    expect(payload["summary"]["violations"]).to eq(1)
    expect(payload["violations"][0]["reason"]).to eq("not allowed")
  end

  it "handles empty input" do
    formatter.render([])

    payload = JSON.parse(output.string)
    expect(payload["gems"]).to eq([])
  end
end
