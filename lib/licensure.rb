# frozen_string_literal: true

require_relative "licensure/version"
require_relative "licensure/errors"
require_relative "licensure/types"
require_relative "licensure/configuration"
require_relative "licensure/dependency_resolver"
require_relative "licensure/license_fetcher"
require_relative "licensure/license_checker"
require_relative "licensure/formatters/base"
require_relative "licensure/formatters/table"
require_relative "licensure/formatters/csv"
require_relative "licensure/formatters/json"
require_relative "licensure/formatters/markdown"
require_relative "licensure/cli"

# Top-level namespace for Licensure.
module Licensure
end
