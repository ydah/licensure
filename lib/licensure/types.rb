# frozen_string_literal: true

module Licensure
  # License information for a single gem dependency.
  GemLicenseInfo = Struct.new(
    :name,
    :version,
    :licenses,
    :source,
    :homepage,
    keyword_init: true
  )

  # License check result aggregation.
  CheckResult = Struct.new(
    :violations,
    :warnings,
    :passed,
    keyword_init: true
  )

  # Violation or warning entry with reason.
  Violation = Struct.new(
    :gem_info,
    :reason,
    keyword_init: true
  )
end
