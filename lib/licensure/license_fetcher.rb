# frozen_string_literal: true

require "json"
require "net/http"

module Licensure
  # Fetches gem license data from local gemspecs and RubyGems API.
  class LicenseFetcher
    RUBYGEMS_ENDPOINT = "https://rubygems.org/api/v1/gems".freeze
    GITHUB_LICENSE_ENDPOINT = "https://api.github.com/repos".freeze
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
      return build_info_from_payload(name, version, local, :gemspec) if local

      remote = fetch_from_api(name)
      return build_info_from_payload(name, version, remote, :api) if remote

      build_info(name, version, [], :unknown, nil)
    end

    private

    # @param name [String]
    # @param version [String]
    # @param payload [Hash]
    # @param source [Symbol]
    # @return [Licensure::GemLicenseInfo]
    def build_info_from_payload(name, version, payload, source)
      licenses = normalize_with_github(
        payload[:licenses],
        payload[:source_code_uri],
        payload[:homepage]
      )
      homepage = payload[:homepage] || payload[:source_code_uri]

      build_info(name, version, licenses, source, homepage)
    end

    # @param name [String]
    # @return [Hash, nil]
    def fetch_from_gemspec(name)
      spec = Gem::Specification.find_by_name(name)
      licenses = normalize_licenses(spec.licenses, spec.license)
      return nil if licenses.empty?

      {
        licenses: licenses,
        homepage: spec.homepage,
        source_code_uri: spec.metadata&.[]("source_code_uri")
      }
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

      {
        licenses: licenses,
        homepage: payload["homepage_uri"] || payload["homepage"],
        source_code_uri: payload["source_code_uri"]
      }
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

    # @param licenses [Array<String>]
    # @param source_code_uri [String, nil]
    # @param homepage [String, nil]
    # @return [Array<String>]
    def normalize_with_github(licenses, source_code_uri, homepage)
      return licenses if licenses.empty?
      return licenses unless github_normalization_needed?(licenses)

      repository = github_repository(source_code_uri || homepage)
      return licenses unless repository

      github_license = fetch_github_license(repository[:owner], repository[:repo])
      return licenses unless github_license

      canonicalize_licenses(
        licenses,
        github_license[:spdx_id],
        github_license[:name],
        github_license[:key]
      )
    end

    # @param licenses [Array<String>]
    # @return [Boolean]
    def github_normalization_needed?(licenses)
      licenses.any? { |license| license.match?(/\s|,|\blicense\b|\bversion\b/i) }
    end

    # @param url [String, nil]
    # @return [Hash{Symbol => String}, nil]
    def github_repository(url)
      return nil if url.to_s.strip.empty?

      uri = URI(url)
      host = uri.host.to_s.downcase
      return nil unless %w[github.com www.github.com].include?(host)

      segments = uri.path.to_s.split("/").reject(&:empty?)
      return nil if segments.size < 2

      owner = segments[0]
      repo = segments[1].sub(/\.git\z/, "")
      return nil if owner.empty? || repo.empty?

      { owner: owner, repo: repo }
    rescue URI::InvalidURIError
      nil
    end

    # @param owner [String]
    # @param repo [String]
    # @return [Hash{Symbol => String}, nil]
    def fetch_github_license(owner, repo)
      uri = URI("#{GITHUB_LICENSE_ENDPOINT}/#{owner}/#{repo}/license")
      request = Net::HTTP::Get.new(uri)
      request["Accept"] = "application/vnd.github+json"
      request["X-GitHub-Api-Version"] = "2022-11-28"
      request["User-Agent"] = "Licensure/#{Licensure::VERSION}"

      token = ENV["GITHUB_TOKEN"]
      request["Authorization"] = "Bearer #{token}" unless token.to_s.empty?

      response = http_client_for(uri).request(request)
      return nil unless response.is_a?(Net::HTTPSuccess)

      payload = JSON.parse(response.body)
      license = payload["license"]
      return nil unless license.is_a?(Hash)

      spdx_id = license["spdx_id"].to_s.strip
      return nil if spdx_id.empty? || spdx_id == "NOASSERTION"

      { spdx_id: spdx_id, name: license["name"], key: license["key"] }
    rescue JSON::ParserError, StandardError
      nil
    end

    # @param licenses [Array<String>]
    # @param spdx_id [String]
    # @param name [String, nil]
    # @param key [String, nil]
    # @return [Array<String>]
    def canonicalize_licenses(licenses, spdx_id, name, key)
      fingerprints = [spdx_id, name, key].filter_map { |value| LicenseMatcher.fingerprint(value) }.uniq
      return licenses if fingerprints.empty?

      licenses.map do |license|
        fingerprint = LicenseMatcher.fingerprint(license)
        fingerprints.include?(fingerprint) ? spdx_id : license
      end.uniq
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
