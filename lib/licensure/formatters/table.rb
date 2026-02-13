# frozen_string_literal: true

module Licensure
  module Formatters
    # Renders terminal-friendly ASCII tables.
    class Table < Base
      LIST_HEADERS = ["Gem", "Version", "License", "Source", "Homepage"].freeze
      CHECK_HEADERS = ["Gem", "Version", "License", "Source", "Reason"].freeze

      # @param gem_license_infos [Array<Licensure::GemLicenseInfo>]
      # @return [String]
      def render(gem_license_infos)
        rows = gem_license_infos.map { |info| gem_row(info) }
        write_output(build_table(LIST_HEADERS, rows))
      end

      # @param check_result [Licensure::CheckResult]
      # @return [String]
      def render_check_result(check_result)
        sections = []
        sections << section("PASSED", build_table(LIST_HEADERS, check_result.passed.map { |info| gem_row(info) }))
        sections << section("VIOLATIONS", build_table(CHECK_HEADERS, check_result.violations.map { |item| violation_row(item) }))
        sections << section("WARNINGS", build_table(CHECK_HEADERS, check_result.warnings.map { |item| violation_row(item) }))

        write_output(sections.join("\n\n"))
      end

      private

      # @param title [String]
      # @param table [String]
      # @return [String]
      def section(title, table)
        "#{title}\n#{table}"
      end

      # @param headers [Array<String>]
      # @param rows [Array<Array<String>>]
      # @return [String]
      def build_table(headers, rows)
        widths = headers.each_with_index.map do |header, index|
          [header.length, *rows.map { |row| row[index].to_s.length }].max
        end

        border = "+-#{widths.map { |width| "-" * width }.join("-+-")}-+"
        header_line = "| #{headers.each_with_index.map { |header, index| header.ljust(widths[index]) }.join(" | ")} |"

        row_lines = rows.map do |row|
          "| #{row.each_with_index.map { |value, index| value.to_s.ljust(widths[index]) }.join(" | ")} |"
        end

        [border, header_line, border, *row_lines, border].join("\n")
      end
    end
  end
end
