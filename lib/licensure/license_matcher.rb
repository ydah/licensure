# frozen_string_literal: true

module Licensure
  # Compares license labels with lightweight normalization.
  module LicenseMatcher
    module_function

    # @param left [String]
    # @param right [String]
    # @return [Boolean]
    def match?(left, right)
      return true if left == right

      left_fingerprint = fingerprint(left)
      right_fingerprint = fingerprint(right)
      return false unless left_fingerprint && right_fingerprint

      left_fingerprint == right_fingerprint
    end

    # @param value [String, nil]
    # @return [String, nil]
    def fingerprint(value)
      normalized = value.to_s.downcase
                        .gsub(/\b(the|license|version)\b/, "")
                        .gsub(/[^a-z0-9]/, "")
      return nil if normalized.empty?

      normalized
    end
  end
end
