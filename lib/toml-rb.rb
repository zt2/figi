# frozen_string_literal: true

unless defined?(TomlRB)
  module TomlRB
    class ParseError < StandardError; end

    module_function

    def load(content)
      Parser.new(content).parse
    end

    class Parser
      def initialize(content)
        @lines = content.each_line
        @data = {}
        @context = @data
      end

      def parse
        @lines.each do |line|
          stripped = strip_comments(line.strip)
          next if stripped.empty?

          if stripped.start_with?('[') && stripped.end_with?(']')
            enter_table(stripped[1..-2])
          else
            parse_assignment(stripped)
          end
        end
        @data
      end

      private

      def strip_comments(line)
        index = line.index('#')
        index ? line[0...index].strip : line
      end

      def enter_table(identifier)
        parts = identifier.split('.').map(&:strip)
        @context = parts.inject(@data) do |memo, part|
          memo[part] ||= {}
          memo[part]
        end
      end

      def parse_assignment(line)
        key, value = line.split('=', 2)
        raise ParseError, "Invalid assignment: #{line}" unless value

        key = key.strip
        value = value.strip
        @context[key] = parse_value(value)
      end

      def parse_value(value)
        case value
        when /^".*"$/
          value[1..-2]
        when /^'.*'$/
          value[1..-2]
        when /^\[.*\]$/
          inner = value[1..-2].strip
          return [] if inner.empty?

          inner.split(',').map { |item| parse_value(item.strip) }
        when /\A[+-]?\d+\z/
          value.to_i
        when /\A[+-]?\d*\.\d+\z/
          value.to_f
        when /\A(true|false)\z/i
          value.casecmp('true').zero?
        else
          value
        end
      end
    end
  end
end
