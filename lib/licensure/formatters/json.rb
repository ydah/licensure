# frozen_string_literal: true

require "json"
require "time"

module Licensure
  module Formatters
    # Renders JSON output for list/check results.
    class Json < Base
      # @param gem_license_infos [Array<Licensure::GemLicenseInfo>]
      # @return [String]
      def render(gem_license_infos)
        payload = {
          generated_at: Time.now.iso8601,
          gems: gem_license_infos.map { |info| gem_payload(info) }
        }

        write_output(JSON.pretty_generate(payload))
      end

      # @param check_result [Licensure::CheckResult]
      # @return [String]
      def render_check_result(check_result)
        payload = {
          generated_at: Time.now.iso8601,
          summary: {
            total: check_result.passed.size + check_result.violations.size + check_result.warnings.size,
            passed: check_result.passed.size,
            violations: check_result.violations.size,
            warnings: check_result.warnings.size
          },
          violations: check_result.violations.map { |violation| violation_payload(violation) },
          warnings: check_result.warnings.map { |warning| violation_payload(warning) },
          passed: check_result.passed.map { |info| gem_payload(info) }
        }

        write_output(JSON.pretty_generate(payload))
      end

      private

      # @param info [Licensure::GemLicenseInfo]
      # @return [Hash]
      def gem_payload(info)
        {
          name: info.name,
          version: info.version,
          licenses: info.licenses,
          source: info.source.to_s,
          homepage: info.homepage
        }
      end

      # @param violation [Licensure::Violation]
      # @return [Hash]
      def violation_payload(violation)
        gem_payload(violation.gem_info).merge(reason: violation.reason)
      end
    end
  end
end
