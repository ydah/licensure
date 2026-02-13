# frozen_string_literal: true

module Licensure
  # Checks dependency licenses against configuration rules.
  class LicenseChecker
    # @param configuration [Licensure::Configuration]
    def initialize(configuration:)
      @configuration = configuration
    end

    # @param gem_license_infos [Array<Licensure::GemLicenseInfo>]
    # @return [Licensure::CheckResult]
    def check(gem_license_infos)
      filtered_infos = gem_license_infos.reject do |info|
        @configuration.ignored_gems.include?(info.name)
      end

      violations = []
      warnings = []
      passed = []

      filtered_infos.each do |info|
        if info.licenses.empty?
          if @configuration.deny_unknown?
            warnings << Violation.new(gem_info: info, reason: "License not specified")
          else
            passed << info
          end
          next
        end

        if @configuration.allowed_licenses.empty?
          passed << info
          next
        end

        disallowed = disallowed_licenses(info.licenses)
        if disallowed.empty?
          passed << info
          next
        end

        reason = "Licenses '#{disallowed.join(", ")}' are not in the allowed list"
        violations << Violation.new(gem_info: info, reason: reason)
      end

      CheckResult.new(violations: violations, warnings: warnings, passed: passed)
    end

    private

    # @param licenses [Array<String>]
    # @return [Array<String>]
    def disallowed_licenses(licenses)
      licenses.reject { |license| @configuration.allowed_licenses.include?(license) }
    end
  end
end
