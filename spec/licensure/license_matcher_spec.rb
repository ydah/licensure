# frozen_string_literal: true

RSpec.describe Licensure::LicenseMatcher do
  describe ".match?" do
    it "matches identical strings" do
      expect(described_class.match?("MIT", "MIT")).to be(true)
    end

    it "matches SPDX and descriptive Apache labels" do
      expect(described_class.match?("Apache-2.0", "Apache License, Version 2.0")).to be(true)
    end

    it "does not match different licenses" do
      expect(described_class.match?("GPL-3.0", "Apache License, Version 2.0")).to be(false)
    end
  end
end
