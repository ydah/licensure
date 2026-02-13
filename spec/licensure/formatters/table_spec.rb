# frozen_string_literal: true

RSpec.describe Licensure::Formatters::Table do
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

  it "renders list output as table" do
    formatter.render([gem_info])

    rendered = output.string
    expect(rendered).to include("| Gem")
    expect(rendered).to include("rails")
    expect(rendered).to include("MIT")
  end

  it "renders check output with sections" do
    result = Licensure::CheckResult.new(
      passed: [gem_info],
      violations: [Licensure::Violation.new(gem_info: gem_info, reason: "not allowed")],
      warnings: []
    )

    formatter.render_check_result(result)

    rendered = output.string
    expect(rendered).to include("PASSED")
    expect(rendered).to include("VIOLATIONS")
    expect(rendered).to include("not allowed")
  end

  it "handles empty input" do
    formatter.render([])

    expect(output.string).to include("| Gem")
  end
end
