# frozen_string_literal: true

require "optionparser"

module Licensure
  # CLI entrypoint and subcommand orchestrator.
  class CLI
    FORMATS = %w[table csv json markdown].freeze

    # @param argv [Array<String>]
    # @param output [IO]
    # @param error_output [IO]
    # @param input [IO]
    def initialize(argv = ARGV, output: $stdout, error_output: $stderr, input: $stdin)
      @argv = argv.dup
      @output = output
      @error_output = error_output
      @input = input
    end

    # @return [Integer]
    def run
      command = @argv.shift

      case command
      when nil, "help", "-h", "--help"
        run_help(@argv.shift)
      when "list"
        run_list
      when "check"
        run_check
      when "init"
        run_init
      when "version"
        run_version
      else
        @error_output.puts("Unknown command: #{command}")
        2
      end
    rescue OptionParser::ParseError, Licensure::Error => e
      @error_output.puts(e.message)
      2
    rescue StandardError => e
      @error_output.puts("Unexpected error: #{e.message}")
      @error_output.puts(e.backtrace.join("\n"))
      2
    end

    private

    # @return [Integer]
    def run_list
      options = {
        format: "table",
        recursive: false,
        output: nil,
        lockfile_path: "Gemfile.lock",
        help: false
      }

      parser = OptionParser.new do |opts|
        opts.banner = "Usage: licensure list [options]"
        opts.on("-f", "--format FORMAT", FORMATS, "Output format: #{FORMATS.join(', ')}") { |value| options[:format] = value }
        opts.on("-r", "--recursive", "Include transitive dependencies") { options[:recursive] = true }
        opts.on("-o", "--output FILE", "Write output to file") { |value| options[:output] = value }
        opts.on("--gemfile-lock PATH", "Path to Gemfile.lock") { |value| options[:lockfile_path] = value }
        opts.on("-h", "--help", "Show help") { options[:help] = true }
      end

      parser.parse!(@argv)
      return print_help(parser) if options[:help]

      assert_no_extra_arguments!

      dependencies = DependencyResolver.new(
        lockfile_path: options[:lockfile_path],
        recursive: options[:recursive]
      ).resolve

      infos = LicenseFetcher.new.fetch_all(dependencies)
      render_to(options[:format], infos: infos, output_path: options[:output])
      0
    end

    # @return [Integer]
    def run_check
      options = {
        config_path: ".licensure.yml",
        format: "table",
        recursive: false,
        lockfile_path: "Gemfile.lock",
        help: false
      }

      parser = OptionParser.new do |opts|
        opts.banner = "Usage: licensure check [options]"
        opts.on("-c", "--config FILE", "Path to .licensure.yml") { |value| options[:config_path] = value }
        opts.on("-r", "--recursive", "Include transitive dependencies") { options[:recursive] = true }
        opts.on("-f", "--format FORMAT", FORMATS, "Output format: #{FORMATS.join(', ')}") { |value| options[:format] = value }
        opts.on("--gemfile-lock PATH", "Path to Gemfile.lock") { |value| options[:lockfile_path] = value }
        opts.on("-h", "--help", "Show help") { options[:help] = true }
      end

      parser.parse!(@argv)
      return print_help(parser) if options[:help]

      assert_no_extra_arguments!

      configuration = Configuration.load(options[:config_path])
      dependencies = DependencyResolver.new(
        lockfile_path: options[:lockfile_path],
        recursive: options[:recursive]
      ).resolve
      infos = LicenseFetcher.new.fetch_all(dependencies)
      result = LicenseChecker.new(configuration: configuration).check(infos)

      formatter_for(options[:format], output: @output).render_check_result(result)
      result.violations.empty? ? 0 : 1
    end

    # @return [Integer]
    def run_init
      parser = OptionParser.new do |opts|
        opts.banner = "Usage: licensure init"
        opts.on("-h", "--help", "Show help") { @output.puts(opts); return 0 }
      end

      parser.parse!(@argv)
      assert_no_extra_arguments!

      config_path = ".licensure.yml"
      if File.exist?(config_path)
        @output.print("#{config_path} already exists. Overwrite? [y/N]: ")
        answer = @input.gets&.strip&.downcase
        unless %w[y yes].include?(answer)
          @output.puts("Aborted")
          return 0
        end
      end

      File.write(config_path, Configuration::SAMPLE_CONFIG)
      @output.puts("Created #{config_path}")
      0
    end

    # @return [Integer]
    def run_version
      @output.puts("Licensure #{Licensure::VERSION}")
      0
    end

    # @param subcommand [String, nil]
    # @return [Integer]
    def run_help(subcommand)
      return print_main_help if subcommand.nil?

      case subcommand
      when "list"
        print_help(build_list_help_parser)
      when "check"
        print_help(build_check_help_parser)
      when "init"
        @output.puts("Usage: licensure init")
        0
      when "version"
        @output.puts("Usage: licensure version")
        0
      else
        @error_output.puts("Unknown help topic: #{subcommand}")
        2
      end
    end

    # @return [Integer]
    def print_main_help
      @output.puts <<~TEXT
        Usage: licensure <command> [options]

        Commands:
          list      Show dependency license information
          check     Validate licenses against .licensure.yml
          init      Create .licensure.yml
          version   Show current version
          help      Show help
      TEXT
      0
    end

    # @param parser [OptionParser]
    # @return [Integer]
    def print_help(parser)
      @output.puts(parser)
      0
    end

    # @return [OptionParser]
    def build_list_help_parser
      OptionParser.new do |opts|
        opts.banner = "Usage: licensure list [options]"
        opts.on("-f", "--format FORMAT", FORMATS)
        opts.on("-r", "--recursive")
        opts.on("-o", "--output FILE")
        opts.on("--gemfile-lock PATH")
      end
    end

    # @return [OptionParser]
    def build_check_help_parser
      OptionParser.new do |opts|
        opts.banner = "Usage: licensure check [options]"
        opts.on("-c", "--config FILE")
        opts.on("-r", "--recursive")
        opts.on("-f", "--format FORMAT", FORMATS)
        opts.on("--gemfile-lock PATH")
      end
    end

    # @param format [String]
    # @param output [IO]
    # @return [Licensure::Formatters::Base]
    def formatter_for(format, output:)
      case format
      when "table"
        Formatters::Table.new(output: output)
      when "csv"
        Formatters::Csv.new(output: output)
      when "json"
        Formatters::Json.new(output: output)
      when "markdown"
        Formatters::Markdown.new(output: output)
      else
        raise CLIError, "Unsupported format: #{format}"
      end
    end

    # @param format [String]
    # @param infos [Array<Licensure::GemLicenseInfo>]
    # @param output_path [String, nil]
    # @return [void]
    def render_to(format, infos:, output_path:)
      if output_path
        File.open(output_path, "w") do |file|
          formatter_for(format, output: file).render(infos)
        end
        return
      end

      formatter_for(format, output: @output).render(infos)
    end

    # @return [void]
    def assert_no_extra_arguments!
      return if @argv.empty?

      raise CLIError, "Unknown arguments: #{@argv.join(' ')}"
    end
  end
end
