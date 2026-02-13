# frozen_string_literal: true

module Licensure
  module Formatters
    # Renders Markdown tables for list/check results.
    class Markdown < Base
      LIST_HEADERS = ["Gem", "Version", "License", "Source", "Homepage"].freeze
      CHECK_HEADERS = ["Gem", "Version", "License", "Source", "Reason"].freeze

      # @param gem_license_infos [Array<Licensure::GemLicenseInfo>]
      # @return [String]
      def render(gem_license_infos)
        rows = gem_license_infos.map { |info| gem_row(info) }
        write_output(markdown_table(LIST_HEADERS, rows))
      end

      # @param check_result [Licensure::CheckResult]
      # @return [String]
      def render_check_result(check_result)
        sections = [
          markdown_section("PASSED", LIST_HEADERS, check_result.passed.map { |info| gem_row(info) }),
          markdown_section("VIOLATIONS", CHECK_HEADERS, check_result.violations.map { |item| violation_row(item) }),
          markdown_section("WARNINGS", CHECK_HEADERS, check_result.warnings.map { |item| violation_row(item) })
        ]

        write_output(sections.join("\n\n"))
      end

      private

      # @param title [String]
      # @param headers [Array<String>]
      # @param rows [Array<Array<String>>]
      # @return [String]
      def markdown_section(title, headers, rows)
        "## #{title}\n\n#{markdown_table(headers, rows)}"
      end

      # @param headers [Array<String>]
      # @param rows [Array<Array<String>>]
      # @return [String]
      def markdown_table(headers, rows)
        header_line = "| #{headers.join(' | ')} |"
        separator = "| #{Array.new(headers.size, '---').join(' | ')} |"
        row_lines = rows.map { |row| "| #{row.map { |value| escape_markdown(value.to_s) }.join(' | ')} |" }

        [header_line, separator, *row_lines].join("\n")
      end

      # @param value [String]
      # @return [String]
      def escape_markdown(value)
        value.gsub("|", "\\|")
      end
    end
  end
end
