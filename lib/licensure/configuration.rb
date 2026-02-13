# frozen_string_literal: true

require "yaml"

module Licensure
  # Loads and validates .licensure.yml configuration.
  class Configuration
    VALID_KEYS = %w[allowed_licenses ignored_gems deny_unknown].freeze

    SAMPLE_CONFIG = <<~YAML.freeze
      # .licensure.yml
      allowed_licenses:
        - MIT
        - Apache-2.0
        - BSD-2-Clause
        - BSD-3-Clause
        - ISC
        - Ruby

      ignored_gems:
        - bundler
        - rake

      # Treat gems with unspecified licenses as warnings
      deny_unknown: true
    YAML

    # @param path [String]
    # @return [Licensure::Configuration]
    def self.load(path = ".licensure.yml")
      raise ConfigurationError, "Configuration file not found: #{path}" unless File.exist?(path)

      payload = YAML.safe_load(File.read(path), aliases: false) || {}
      unless payload.is_a?(Hash)
        raise ConfigurationError, "Configuration must be a mapping"
      end

      new(payload.transform_keys(&:to_s))
    rescue Psych::SyntaxError => e
      raise ConfigurationError, "Failed to parse configuration: #{e.message}"
    end

    # @return [Licensure::Configuration]
    def self.default
      new({})
    end

    attr_reader :allowed_licenses, :ignored_gems

    # @param data [Hash]
    def initialize(data)
      warn_unknown_keys(data)

      @allowed_licenses = validate_array!(data.fetch("allowed_licenses", []), "allowed_licenses")
      @ignored_gems = validate_array!(data.fetch("ignored_gems", []), "ignored_gems")
      @deny_unknown = validate_boolean!(data.fetch("deny_unknown", true), "deny_unknown")
    end

    # @return [Boolean]
    def deny_unknown?
      @deny_unknown
    end

    private

    # @param data [Hash]
    # @return [void]
    def warn_unknown_keys(data)
      (data.keys - VALID_KEYS).each do |key|
        $stderr.puts("Warning: Unknown configuration key '#{key}'")
      end
    end

    # @param value [Object]
    # @param key [String]
    # @return [Array<String>]
    def validate_array!(value, key)
      unless value.is_a?(Array)
        raise ConfigurationError, "#{key} must be an array"
      end

      value.map(&:to_s)
    end

    # @param value [Object]
    # @param key [String]
    # @return [Boolean]
    def validate_boolean!(value, key)
      unless value == true || value == false
        raise ConfigurationError, "#{key} must be a boolean"
      end

      value
    end
  end
end
