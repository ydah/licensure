# frozen_string_literal: true

require "csv"

module Licensure
  module Formatters
    # Renders CSV output for list/check results.
    class Csv < Base
      # @param gem_license_infos [Array<Licensure::GemLicenseInfo>]
      # @return [String]
      def render(gem_license_infos)
        content = ::CSV.generate do |csv|
          csv << %w[Gem Version License Source Homepage]
          gem_license_infos.each do |info|
            csv << gem_row(info)
          end
        end

        write_output(content)
      end

      # @param check_result [Licensure::CheckResult]
      # @return [String]
      def render_check_result(check_result)
        content = ::CSV.generate do |csv|
          csv << %w[Gem Version License Source Status Reason]

          check_result.passed.each do |info|
            csv << gem_row(info).take(4) + ["PASSED", ""]
          end

          check_result.violations.each do |violation|
            csv << violation_row(violation).take(4) + ["VIOLATION", violation.reason]
          end

          check_result.warnings.each do |warning|
            csv << violation_row(warning).take(4) + ["WARNING", warning.reason]
          end
        end

        write_output(content)
      end
    end
  end
end
