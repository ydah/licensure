# frozen_string_literal: true

require "json"
require "net/http"

module Licensure
  # Fetches gem license data from local gemspecs and RubyGems API.
  class LicenseFetcher
    RUBYGEMS_ENDPOINT = "https://rubygems.org/api/v1/gems".freeze
    REQUEST_TIMEOUT = 5

    # @param dependencies [Array<Hash{Symbol => String}>]
    # @return [Array<Licensure::GemLicenseInfo>]
    def fetch_all(dependencies)
      dependencies.map { |dependency| fetch(dependency[:name], dependency[:version]) }
    end

    # @param name [String]
    # @param version [String]
    # @return [Licensure::GemLicenseInfo]
    def fetch(name, version)
      local = fetch_from_gemspec(name)
      return build_info(name, version, local[:licenses], :gemspec, local[:homepage]) if local

      remote = fetch_from_api(name)
      return build_info(name, version, remote[:licenses], :api, remote[:homepage]) if remote

      build_info(name, version, [], :unknown, nil)
    end

    private

    # @param name [String]
    # @return [Hash, nil]
    def fetch_from_gemspec(name)
      spec = Gem::Specification.find_by_name(name)
      licenses = normalize_licenses(spec.licenses, spec.license)
      return nil if licenses.empty?

      { licenses: licenses, homepage: spec.homepage }
    rescue Gem::LoadError
      nil
    end

    # @param name [String]
    # @return [Hash, nil]
    def fetch_from_api(name)
      uri = URI("#{RUBYGEMS_ENDPOINT}/#{name}.json")
      request = Net::HTTP::Get.new(uri)
      request["User-Agent"] = "Licensure/#{Licensure::VERSION}"

      response = http_client_for(uri).request(request)
      return nil unless response.is_a?(Net::HTTPSuccess)

      payload = JSON.parse(response.body)
      licenses = normalize_licenses(payload["licenses"], payload["license"])
      return nil if licenses.empty?

      { licenses: licenses, homepage: payload["homepage_uri"] || payload["homepage"] }
    rescue JSON::ParserError, StandardError
      nil
    end

    # @param uri [URI::HTTPS]
    # @return [Net::HTTP]
    def http_client_for(uri)
      client = Net::HTTP.new(uri.host, uri.port)
      client.use_ssl = true
      client.open_timeout = REQUEST_TIMEOUT
      client.read_timeout = REQUEST_TIMEOUT
      client
    end

    # @param licenses [Array<String>, nil]
    # @param license [String, nil]
    # @return [Array<String>]
    def normalize_licenses(licenses, license)
      items = []
      items.concat(Array(licenses))
      items << license if license

      items.compact
           .map { |item| item.to_s.strip }
           .reject(&:empty?)
           .uniq
    end

    # @param name [String]
    # @param version [String]
    # @param licenses [Array<String>]
    # @param source [Symbol]
    # @param homepage [String, nil]
    # @return [Licensure::GemLicenseInfo]
    def build_info(name, version, licenses, source, homepage)
      GemLicenseInfo.new(
        name: name,
        version: version,
        licenses: licenses,
        source: source,
        homepage: homepage
      )
    end
  end
end
