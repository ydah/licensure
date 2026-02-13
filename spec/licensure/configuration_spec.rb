# frozen_string_literal: true

require "tmpdir"

RSpec.describe Licensure::Configuration do
  describe ".load" do
    it "loads a valid YAML file" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, ".licensure.yml")
        File.write(path, <<~YAML)
          allowed_licenses:
            - MIT
          ignored_gems:
            - bundler
          deny_unknown: false
        YAML

        config = described_class.load(path)

        expect(config.allowed_licenses).to eq(["MIT"])
        expect(config.ignored_gems).to eq(["bundler"])
        expect(config.deny_unknown?).to be(false)
      end
    end

    it "raises when file does not exist" do
      expect { described_class.load("missing.yml") }
        .to raise_error(Licensure::ConfigurationError, /Configuration file not found/)
    end

    it "warns for unknown keys" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, ".licensure.yml")
        File.write(path, <<~YAML)
          allowed_licenses: []
          ignored_gems: []
          deny_unknown: true
          extra_key: value
        YAML

        original_stderr = $stderr
        $stderr = StringIO.new

        described_class.load(path)

        expect($stderr.string).to include("Unknown configuration key 'extra_key'")
      ensure
        $stderr = original_stderr
      end
    end

    it "raises for invalid allowed_licenses type" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, ".licensure.yml")
        File.write(path, <<~YAML)
          allowed_licenses: MIT
        YAML

        expect { described_class.load(path) }
          .to raise_error(Licensure::ConfigurationError, /allowed_licenses must be an array/)
      end
    end

    it "raises for invalid ignored_gems type" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, ".licensure.yml")
        File.write(path, <<~YAML)
          ignored_gems: bundler
        YAML

        expect { described_class.load(path) }
          .to raise_error(Licensure::ConfigurationError, /ignored_gems must be an array/)
      end
    end
  end

  describe ".default" do
    it "returns defaults" do
      config = described_class.default

      expect(config.allowed_licenses).to eq([])
      expect(config.ignored_gems).to eq([])
      expect(config.deny_unknown?).to be(true)
    end
  end
end
