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

        if allowed_license?(info.licenses)
          passed << info
          next
        end

        reason = "License '#{info.licenses.join(", ")}' is not in the allowed list"
        violations << Violation.new(gem_info: info, reason: reason)
      end

      CheckResult.new(violations: violations, warnings: warnings, passed: passed)
    end

    private

    # @param licenses [Array<String>]
    # @return [Boolean]
    def allowed_license?(licenses)
      licenses.any? { |license| @configuration.allowed_licenses.include?(license) }
    end
  end
end
