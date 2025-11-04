# frozen_string_literal: true

#
# Standard library
#
require 'forwardable'
require 'json'
require 'logger'
require 'singleton'
require 'yaml'

#
# Third party library
#
require 'hashie'
require 'toml-rb'
require 'listen'

require_relative 'env_binding'

module Figi
  class ConfigError < StandardError; end
  class ConfigFileNotFoundError < ConfigError; end
  class ConfigParseError < ConfigError; end
  class ConfigRemoteError < ConfigError; end
  class ConfigTypeError < ConfigError; end

  #
  # Core class responsible for managing configuration coming from a set of
  # ordered sources (defaults, files, remote providers, environment variables
  # and command line overrides).
  #
  class Config
    extend Forwardable
    include Singleton

    SourcePriority = %i[defaults files remote env cli].freeze
    FILE_EXTENSIONS = {
      '.json' => :json,
      '.yml' => :yaml,
      '.yaml' => :yaml,
      '.toml' => :toml
    }.freeze

    attr_accessor :logger
    attr_reader :config_paths, :config_name, :env_binding

    class << self
      def from_json(path)
        instance.load_from_file(path, format: :json)
      end

      def from_yaml(path)
        instance.load_from_file(path, format: :yaml)
      end

      def load(config = nil, source: :cli, read_files: true, read_env: true, read_remote: true, watch_files: false, &block)
        instance.load_all(config, source: source, read_files: read_files, read_env: read_env,
                                   read_remote: read_remote, watch_files: watch_files, &block)
      end

      def register_defaults(values = nil, &block)
        instance.register_defaults(values, &block)
      end

      def register_alias(alias_key, canonical_key)
        instance.register_alias(alias_key, canonical_key)
      end

      def add_config_path(path)
        instance.add_config_path(path)
      end

      def set_config_name(name)
        instance.set_config_name(name)
      end

      def read_in_config(watch: false)
        instance.read_in_config(watch: watch)
      end

      def load_env(env = ENV)
        instance.load_env(env)
      end

      def bind_env(env_key, config_key, &transformer)
        instance.bind_env(env_key, config_key, &transformer)
      end

      def configure_env(prefix: nil, separator: nil, &block)
        instance.configure_env(prefix: prefix, separator: separator, &block)
      end

      def register_remote_source(name, interval: nil, &loader)
        instance.register_remote_source(name, interval: interval, &loader)
      end

      def refresh_remote_source(name)
        instance.refresh_remote_source(name)
      end

      def reset!
        instance.reset!
      end

      def on_change(&block)
        instance.on_change(&block)
      end
    end

    def initialize
      setup_state
    end

    def register_defaults(values = nil, &block)
      defaults = build_hash(values, &block)
      @source_data[:defaults][:defaults] = normalize_structure(defaults)
      rebuild_table!
    end

    def register_alias(alias_key, canonical_key)
      @aliases[alias_key.to_s] = canonical_key.to_s
      rebuild_table!
    end

    def add_config_path(path)
      expanded = File.expand_path(path)
      @config_paths << expanded unless @config_paths.include?(expanded)
      self
    end

    def set_config_name(name)
      @config_name = name.to_s
      self
    end

    def read_in_config(watch: false)
      found = false
      @source_data[:files] = {}

      @config_paths.each do |path|
        base = File.join(path, @config_name)
        FILE_EXTENSIONS.each_key do |ext|
          file_path = "#{base}#{ext}"
          next unless File.file?(file_path)

          found = true
          load_from_file(file_path, source: :files, name: file_path)
          watch_file(file_path) if watch
        end
      end

      rebuild_table!
      found
    end

    def load_env(env = ENV)
      data = @env_binding.read(env)
      @source_data[:env][:env] = normalize_structure(data)
      rebuild_table!
    end

    def bind_env(env_key, config_key, &transformer)
      @env_binding.bind(env_key, config_key, &transformer)
      self
    end

    def configure_env(prefix: nil, separator: nil, &block)
      @env_binding.prefix = prefix unless prefix.nil?
      @env_binding.separator = separator unless separator.nil?
      block&.call(@env_binding)
      self
    end

    def register_remote_source(name, interval: nil, &loader)
      raise ArgumentError, 'Loader block is required for remote source' unless loader

      adapter = RemoteAdapter.new(name, loader: loader, interval: interval, logger: logger) do |payload|
        @source_data[:remote][name.to_sym] = normalize_structure(payload || {})
        rebuild_table!
      end
      @remote_sources[name.to_sym] = adapter
      adapter
    end

    def refresh_remote_source(name)
      adapter = @remote_sources[name.to_sym]
      return unless adapter

      adapter.poll
    end

    def start_remote_sources
      @remote_sources.each_value(&:start)
    end

    def stop_remote_sources
      @remote_sources.each_value(&:stop)
    end

    def load_all(config = nil, source: :cli, read_files: true, read_env: true, read_remote: true, watch_files: false)
      read_in_config(watch: watch_files) if read_files
      load_env if read_env
      @remote_sources.each_key { |name| refresh_remote_source(name) } if read_remote

      clear_source(source, :runtime)
      payload = build_hash(config) do |mash|
        yield mash if block_given?
      end
      @source_data[source][:runtime] = normalize_structure(payload)
      rebuild_table!
      @table
    end

    def load_from_file(path, format: nil, source: :files, name: path)
      absolute_path = File.expand_path(path)
      format ||= detect_format(absolute_path)
      content = safely_read_file(absolute_path)
      data = parse_content(content, format, absolute_path)
      @source_data[source][source_entry_key(name)] = normalize_structure(data)
      rebuild_table!
      @table
    rescue ConfigError
      raise
    rescue StandardError => e
      logger.error("Unexpected error loading #{absolute_path}: #{e.class}: #{e.message}")
      raise ConfigError, e.message
    end

    def watch_file(path)
      absolute_path = File.expand_path(path)
      watcher = @file_watchers[absolute_path]

      unless watcher
        watcher = FileWatcher.new(absolute_path, logger: logger) do
          handle_file_change(absolute_path)
        end
        @file_watchers[absolute_path] = watcher
      end

      watcher.start
      watcher
    end

    def simulate_file_change(path)
      absolute_path = File.expand_path(path)
      if (watcher = @file_watchers[absolute_path])
        watcher.trigger
      else
        handle_file_change(absolute_path)
      end
    end

    def handle_file_change(path)
      load_from_file(path, source: :files, name: path)
    rescue ConfigError => e
      logger.error("Failed to reload #{path}: #{e.message}")
    end

    def get(key)
      fetch_value(key)
    end

    def get_string(key, default = nil)
      value = fetch_value(key)
      return default if value.nil?

      value.to_s
    end

    def get_int(key, default = nil)
      value = fetch_value(key)
      return default if value.nil?

      Integer(value)
    rescue ArgumentError, TypeError
      raise ConfigTypeError, "Expected integer for #{key}"
    end

    def get_float(key, default = nil)
      value = fetch_value(key)
      return default if value.nil?

      Float(value)
    rescue ArgumentError, TypeError
      raise ConfigTypeError, "Expected float for #{key}"
    end

    def get_bool(key, default = nil)
      value = fetch_value(key)
      return default if value.nil?

      case value
      when true, false
        value
      when String
        return true if value.strip.casecmp('true').zero?
        return false if value.strip.casecmp('false').zero?
      end

      raise ConfigTypeError, "Expected boolean for #{key}"
    end

    def get_array(key, default = nil)
      value = fetch_value(key)
      return default if value.nil?
      return value if value.is_a?(Array)

      raise ConfigTypeError, "Expected array for #{key}"
    end

    def get_hash(key, default = nil)
      value = fetch_value(key)
      return default if value.nil?
      return value if value.is_a?(Hash) || value.is_a?(Hashie::Mash)

      raise ConfigTypeError, "Expected hash for #{key}"
    end

    def [](key)
      fetch_value(key)
    end

    def on_change(&block)
      @callbacks << block if block
      self
    end

    def reset!
      stop_remote_sources
      @file_watchers.each_value(&:stop)
      setup_state
      self
    end

    def method_missing(method_name, *args, &block)
      if @table.respond_to?(method_name)
        @table.public_send(method_name, *args, &block)
      else
        super
      end
    end

    def respond_to_missing?(method_name, include_private = false)
      @table.respond_to?(method_name) || super
    end

    def_delegators :@table, :inspect, :to_json, :to_h, :to_yaml, :to_s

    private

    def setup_state
      @logger = Logger.new($stdout)
      @logger.progname = 'Figi::Config'
      @source_data = Hash.new { |hash, key| hash[key] = {} }
      @config_paths = [Dir.pwd]
      @config_name = 'config'
      @aliases = {}
      @env_binding = Figi::EnvBinding.new
      @file_watchers = {}
      @remote_sources = {}
      @callbacks = []
      @table = Hashie::Mash.new
    end

    def clear_source(source, name = nil)
      if name
        @source_data[source].delete(name)
      else
        @source_data[source] = {}
      end
    end

    def rebuild_table!
      previous = deep_copy(@table.to_h)
      merged = {}

      SourcePriority.each do |source|
        collection = @source_data[source]
        if collection.is_a?(Hash)
          collection.values.each do |value|
            merged = deep_merge(merged, value)
          end
        else
          merged = deep_merge(merged, collection)
        end
      end

      if previous != merged
        @table = Hashie::Mash.new(merged)
        notify_change
      else
        @table = Hashie::Mash.new(merged)
      end
    end

    def notify_change
      @callbacks.each do |callback|
        safe_call { callback.call(@table) }
      end
    end

    def safe_call
      yield
    rescue StandardError => e
      logger.error("Callback execution failed: #{e.class}: #{e.message}")
    end

    def build_hash(values = nil)
      mash = Hashie::Mash.new
      mash.merge!(values) if values
      yield mash if block_given?
      mash.to_h
    end

    def detect_format(path)
      ext = File.extname(path).downcase
      FILE_EXTENSIONS[ext] || raise(ConfigParseError, "Unknown config format for #{path}")
    end

    def safely_read_file(path)
      File.read(path)
    rescue Errno::ENOENT => e
      logger.error("Configuration file not found: #{path}")
      raise ConfigFileNotFoundError, e.message
    rescue Errno::EACCES => e
      logger.error("Configuration file not readable: #{path}")
      raise ConfigFileNotFoundError, e.message
    end

    def parse_content(content, format, path)
      case format
      when :json
        JSON.parse(content)
      when :yaml
        YAML.safe_load(content, aliases: true)
      when :toml
        TomlRB.load(content)
      else
        raise ConfigParseError, "Unsupported config format for #{path}"
      end
    rescue JSON::ParserError, Psych::SyntaxError, TomlRB::ParseError => e
      logger.error("Failed to parse configuration #{path}: #{e.message}")
      raise ConfigParseError, e.message
    end

    def normalize_structure(data)
      case data
      when Hashie::Mash
        normalize_structure(data.to_h)
      when Hash
        data.each_with_object({}) do |(key, value), memo|
          canonical = normalize_key(key)
          assign_nested_value(memo, canonical.split('.'), normalize_structure(value))
        end
      when Array
        data.map { |entry| normalize_structure(entry) }
      else
        data
      end
    end

    def assign_nested_value(container, segments, value)
      key = segments.shift
      if segments.empty?
        container[key] = merge_leaf(container[key], value)
      else
        container[key] = {} unless container[key].is_a?(Hash)
        assign_nested_value(container[key], segments, value)
      end
    end

    def merge_leaf(existing, value)
      if existing.is_a?(Hash) && value.is_a?(Hash)
        deep_merge(existing, value)
      else
        value
      end
    end

    def normalize_key(key)
      canonical = @aliases[key.to_s] || key.to_s
      canonical
    end

    def source_entry_key(name)
      name.is_a?(Symbol) ? name : name.to_s
    end

    def deep_merge(base, other)
      result = deep_copy(base)
      other.each do |key, value|
        result[key] = if result.key?(key)
                        merge_values(result[key], value)
                      else
                        convert_value(value)
                      end
      end
      result
    end

    def merge_values(left, right)
      if left.is_a?(Hash) && right.is_a?(Hash)
        deep_merge(left, right)
      else
        convert_value(right)
      end
    end

    def convert_value(value)
      case value
      when Hash
        value.each_with_object({}) do |(k, v), memo|
          memo[k] = convert_value(v)
        end
      when Hashie::Mash
        convert_value(value.to_h)
      when Array
        value.map { |item| convert_value(item) }
      else
        value
      end
    end

    def deep_copy(object)
      Marshal.load(Marshal.dump(object))
    rescue TypeError
      object.dup
    end

    def fetch_value(key)
      canonical = normalize_key(key)
      segments = canonical.split('.')
      segments.reduce(@table) do |memo, segment|
        break nil if memo.nil?

        if memo.is_a?(Hashie::Mash)
          memo = memo[segment]
        elsif memo.is_a?(Hash)
          memo = memo[segment] || memo[segment.to_sym]
        else
          break nil
        end
      end
    end

    class RemoteAdapter
      def initialize(name, loader:, interval:, logger:, &callback)
        @name = name
        @loader = loader
        @interval = interval
        @logger = logger
        @callback = callback
        @thread = nil
      end

      def start
        return unless @callback

        poll
        return unless @interval

        @thread&.kill
        @thread = Thread.new do
          loop do
            sleep @interval
            poll
          rescue ConfigRemoteError => e
            @logger.error("Remote source #{@name} failed: #{e.message}")
          rescue StandardError => e
            @logger.error("Remote source #{@name} crashed: #{e.class}: #{e.message}")
          end
        end
      end

      def stop
        @thread&.kill
        @thread = nil
      end

      def poll
        data = fetch
        @callback&.call(data)
        data
      end

      private

      def fetch
        @loader.call
      rescue ConfigError
        raise
      rescue StandardError => e
        raise ConfigRemoteError, e.message
      end
    end

    class FileWatcher
      def initialize(path, logger:, &callback)
        @path = path
        @logger = logger
        @callback = callback
        @listener = build_listener
        @started = false
      end

      def start
        return if @started

        @listener&.start
        @started = true
      end

      def stop
        @listener&.stop
        @started = false
      end

      def trigger
        @callback&.call
      end

      private

      def build_listener
        Listen.to(File.dirname(@path)) do |modified, added, _removed|
          changed = (modified + added).map { |file| File.expand_path(file) }
          target = File.expand_path(@path)
          @callback&.call if changed.include?(target)
        end
      rescue StandardError => e
        @logger.warn("File watching disabled for #{@path}: #{e.message}")
        nil
      end
    end
  end
end
