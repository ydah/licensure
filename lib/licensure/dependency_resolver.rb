# frozen_string_literal: true

require "bundler"

module Licensure
  # Parses Gemfile.lock and resolves dependency names/versions.
  class DependencyResolver
    # @param lockfile_path [String]
    # @param recursive [Boolean]
    def initialize(lockfile_path: "Gemfile.lock", recursive: false)
      @lockfile_path = lockfile_path
      @recursive = recursive
    end

    # @return [Array<Hash{Symbol => String}>]
    def resolve
      raise DependencyResolutionError, "Gemfile.lock not found: #{@lockfile_path}" unless File.exist?(@lockfile_path)

      parser = Bundler::LockfileParser.new(File.read(@lockfile_path))
      specs_by_name = parser.specs.to_h { |spec| [spec.name, spec] }

      names = if @recursive
        parser.specs.map(&:name)
      else
        parser.dependencies.keys
      end

      names.uniq
           .reject { |name| name == "bundler" }
           .filter_map do |name|
             spec = specs_by_name[name]
             next unless spec

             { name: name, version: spec.version.to_s }
           end
           .sort_by { |dependency| dependency[:name] }
    rescue Bundler::LockfileError => e
      raise DependencyResolutionError, "Failed to parse #{@lockfile_path}: #{e.message}"
    end
  end
end
