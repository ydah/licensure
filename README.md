# Licensure

Licensure is a RubyGem CLI tool that inspects dependency licenses from `Gemfile.lock` and checks them against a configurable allow list.

## Installation

Install as a gem:

```bash
gem install licensure
```

Or add it to your `Gemfile`:

```ruby
gem "licensure"
```

## Quick Start

Initialize config:

```bash
licensure init
```

List dependency licenses:

```bash
licensure list
```

Check licenses against `.licensure.yml`:

```bash
licensure check
```

## Configuration

Licensure uses `.licensure.yml`:

```yaml
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

deny_unknown: true
```

- `allowed_licenses`: Allowed license identifiers. Empty means allow all.
- `ignored_gems`: Gem names excluded from checks.
- `deny_unknown`: Treat gems without license metadata as warnings.

## Commands

```bash
licensure list [--format table|csv|json|markdown] [--recursive] [--output FILE] [--gemfile-lock PATH]
licensure check [--config FILE] [--recursive] [--format table|csv|json|markdown] [--gemfile-lock PATH]
licensure init
licensure version
licensure help [command]
```

## Output Formats

`list` and `check` support:

- `table`
- `csv`
- `json`
- `markdown`

Example:

```bash
licensure list --format json
licensure check --format markdown
```

## CI Example (GitHub Actions)

```yaml
name: License Check
on: [push, pull_request]
jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: ruby/setup-ruby@v1
        with:
          ruby-version: "3.3"
          bundler-cache: true
      - run: gem install licensure
      - run: licensure check
```

## Development

```bash
bundle install
bundle exec rake spec
```

## License

Released under the MIT License. See `LICENSE.txt`.
