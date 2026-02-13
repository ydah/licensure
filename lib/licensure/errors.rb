# frozen_string_literal: true

module Licensure
  # Base error class for Licensure.
  class Error < StandardError; end

  # Raised when configuration loading or validation fails.
  class ConfigurationError < Error; end

  # Raised when Gemfile.lock parsing fails.
  class DependencyResolutionError < Error; end

  # Raised for CLI argument and execution failures.
  class CLIError < Error; end
end
