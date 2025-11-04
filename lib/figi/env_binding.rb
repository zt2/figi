# frozen_string_literal: true

module Figi
  #
  # EnvBinding encapsulates the behaviour required to load configuration values
  # from environment variables. It supports configurable prefixes, key
  # formatting, manual bindings and type coercion.
  #
  class EnvBinding
    attr_reader :prefix, :separator

    def initialize(prefix: 'FIGI', separator: '_', &block)
      @prefix = prefix
      @separator = separator
      @formatter = method(:default_formatter)
      @bindings = {}
      instance_eval(&block) if block
    end

    def prefix=(value)
      @prefix = value
      @auto_prefix = nil
    end

    def separator=(value)
      @separator = value
      @auto_prefix = nil
    end

    def bind(env_key, config_key, &transformer)
      @bindings[env_key.to_s] = { key: config_key.to_s, transformer: transformer }
      self
    end

    def set_formatter(&block)
      @formatter = block if block
      self
    end

    def read(env = ENV)
      result = {}

      env.each do |key, value|
        if (binding = @bindings[key.to_s])
          assign(result, binding[:key], transform_value(value, binding[:transformer]))
        elsif auto_binding?(key)
          assign(result, auto_key(key), coerce(value))
        end
      end

      result
    end

    private

    def auto_binding?(key)
      return false unless @prefix

      key.start_with?(auto_prefix)
    end

    def auto_key(env_key)
      raw = env_key.sub(auto_prefix, '')
      segments = raw.split(@separator)
      formatted = @formatter ? @formatter.call(segments) : default_formatter(segments)
      formatted.to_s
    end

    def auto_prefix
      @auto_prefix ||= begin
        prefix = [@prefix, @separator].join
        prefix.empty? ? '' : prefix
      end
    end

    def assign(container, canonical_key, value)
      parts = canonical_key.to_s.split('.')
      leaf = parts.pop
      node = parts.inject(container) do |memo, part|
        memo[part] ||= {}
        memo[part]
      end
      node[leaf] = value
    end

    def transform_value(value, transformer)
      return transformer.call(value) if transformer

      coerce(value)
    end

    def coerce(value)
      return value if value.nil?
      return value if value.is_a?(Numeric) || value == true || value == false

      string = value.to_s
      case string
      when /\A[+-]?\d+\z/
        string.to_i
      when /\A[+-]?\d*\.\d+\z/
        string.to_f
      when /\A(true|false)\z/i
        string.casecmp('true').zero?
      else
        string
      end
    end

    def default_formatter(segments)
      segments.map { |segment| segment.downcase }.join('.')
    end
  end
end
