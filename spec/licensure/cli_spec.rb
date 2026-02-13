# frozen_string_literal: true

require "tmpdir"

RSpec.describe Licensure::CLI do
  let(:stdout) { StringIO.new }
  let(:stderr) { StringIO.new }

  let(:gem_info) do
    Licensure::GemLicenseInfo.new(
      name: "rails",
      version: "7.1.0",
      licenses: ["MIT"],
      source: :gemspec,
      homepage: "https://rubyonrails.org"
    )
  end

  describe "#run" do
    it "returns exit 2 for unknown command" do
      status = described_class.new(["unknown"], output: stdout, error_output: stderr).run

      expect(status).to eq(2)
      expect(stderr.string).to include("Unknown command")
    end

    it "shows list help" do
      status = described_class.new(%w[list --help], output: stdout, error_output: stderr).run

      expect(status).to eq(0)
      expect(stdout.string).to include("Usage: licensure list")
    end

    it "passes recursive flag to dependency resolver" do
      resolver = instance_double(Licensure::DependencyResolver, resolve: [])
      fetcher = instance_double(Licensure::LicenseFetcher, fetch_all: [])
      formatter = instance_double(Licensure::Formatters::Table, render: true)

      allow(Licensure::DependencyResolver).to receive(:new).and_return(resolver)
      allow(Licensure::LicenseFetcher).to receive(:new).and_return(fetcher)
      allow(Licensure::Formatters::Table).to receive(:new).and_return(formatter)

      status = described_class.new(%w[list --recursive], output: stdout, error_output: stderr).run

      expect(status).to eq(0)
      expect(Licensure::DependencyResolver)
        .to have_received(:new)
        .with(lockfile_path: "Gemfile.lock", recursive: true)
    end

    it "uses json formatter for list --format json" do
      resolver = instance_double(Licensure::DependencyResolver, resolve: [{ name: "rails", version: "7.1.0" }])
      fetcher = instance_double(Licensure::LicenseFetcher, fetch_all: [gem_info])
      formatter = instance_double(Licensure::Formatters::Json, render: true)

      allow(Licensure::DependencyResolver).to receive(:new).and_return(resolver)
      allow(Licensure::LicenseFetcher).to receive(:new).and_return(fetcher)
      allow(Licensure::Formatters::Json).to receive(:new).and_return(formatter)

      status = described_class.new(%w[list --format json], output: stdout, error_output: stderr).run

      expect(status).to eq(0)
      expect(formatter).to have_received(:render).with([gem_info])
    end

    it "returns exit 1 when check finds violations" do
      configuration = Licensure::Configuration.default
      result = Licensure::CheckResult.new(
        passed: [],
        violations: [Licensure::Violation.new(gem_info: gem_info, reason: "not allowed")],
        warnings: []
      )

      resolver = instance_double(Licensure::DependencyResolver, resolve: [{ name: "rails", version: "7.1.0" }])
      fetcher = instance_double(Licensure::LicenseFetcher, fetch_all: [gem_info])
      checker = instance_double(Licensure::LicenseChecker, check: result)
      formatter = instance_double(Licensure::Formatters::Table, render_check_result: true)

      allow(Licensure::Configuration).to receive(:load).and_return(configuration)
      allow(Licensure::DependencyResolver).to receive(:new).and_return(resolver)
      allow(Licensure::LicenseFetcher).to receive(:new).and_return(fetcher)
      allow(Licensure::LicenseChecker).to receive(:new).with(configuration: configuration).and_return(checker)
      allow(Licensure::Formatters::Table).to receive(:new).and_return(formatter)

      status = described_class.new(%w[check], output: stdout, error_output: stderr).run

      expect(status).to eq(1)
    end

    it "returns exit 0 when check has no violations" do
      configuration = Licensure::Configuration.default
      result = Licensure::CheckResult.new(passed: [gem_info], violations: [], warnings: [])

      resolver = instance_double(Licensure::DependencyResolver, resolve: [{ name: "rails", version: "7.1.0" }])
      fetcher = instance_double(Licensure::LicenseFetcher, fetch_all: [gem_info])
      checker = instance_double(Licensure::LicenseChecker, check: result)
      formatter = instance_double(Licensure::Formatters::Table, render_check_result: true)

      allow(Licensure::Configuration).to receive(:load).and_return(configuration)
      allow(Licensure::DependencyResolver).to receive(:new).and_return(resolver)
      allow(Licensure::LicenseFetcher).to receive(:new).and_return(fetcher)
      allow(Licensure::LicenseChecker).to receive(:new).with(configuration: configuration).and_return(checker)
      allow(Licensure::Formatters::Table).to receive(:new).and_return(formatter)

      status = described_class.new(%w[check], output: stdout, error_output: stderr).run

      expect(status).to eq(0)
    end

    it "creates .licensure.yml with init" do
      Dir.mktmpdir do |dir|
        Dir.chdir(dir) do
          status = described_class.new(%w[init], output: stdout, error_output: stderr, input: StringIO.new).run

          expect(status).to eq(0)
          expect(File.exist?(".licensure.yml")).to be(true)
          expect(File.read(".licensure.yml")).to include("allowed_licenses")
        end
      end
    end

    it "returns exit 2 when Gemfile.lock is missing" do
      status = described_class.new(%w[list --gemfile-lock missing.lock], output: stdout, error_output: stderr).run

      expect(status).to eq(2)
      expect(stderr.string).to include("Gemfile.lock not found")
    end

    it "returns exit 2 when config file is missing" do
      status = described_class.new(%w[check --config missing.yml], output: stdout, error_output: stderr).run

      expect(status).to eq(2)
      expect(stderr.string).to include("Configuration file not found")
    end
  end
end
