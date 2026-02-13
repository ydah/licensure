# frozen_string_literal: true

module Licensure
  module Formatters
    # Base formatter abstraction.
    class Base
      # @param output [IO]
      def initialize(output: $stdout)
        @output = output
      end

      # @param _gem_license_infos [Array<Licensure::GemLicenseInfo>]
      # @return [String]
      def render(_gem_license_infos)
        raise NotImplementedError, "Implement #render in formatter subclasses"
      end

      # @param _check_result [Licensure::CheckResult]
      # @return [String]
      def render_check_result(_check_result)
        raise NotImplementedError, "Implement #render_check_result in formatter subclasses"
      end

      protected

      # @param content [String]
      # @return [String]
      def write_output(content)
        @output.write(content)
        @output.write("\n") unless content.end_with?("\n")
        content
      end

      # @param info [Licensure::GemLicenseInfo]
      # @return [Array<String>]
      def gem_row(info)
        [
          info.name.to_s,
          info.version.to_s,
          info.licenses.join(" | "),
          info.source.to_s,
          info.homepage.to_s
        ]
      end

      # @param violation [Licensure::Violation]
      # @return [Array<String>]
      def violation_row(violation)
        row = gem_row(violation.gem_info).take(4)
        row << violation.reason.to_s
      end
    end
  end
end
