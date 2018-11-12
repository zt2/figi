#
# Standard library
#
require 'forwardable'
require 'json'
require 'singleton'
require 'yaml'

#
# Third party library
#
require 'hashie'

module Figi
  #
  # Core class
  #
  class Config
    extend Forwardable
    include Singleton

    class << self
      # Load config from json file
      #
      # @param path [String] File path
      # @example
      #   Figi::Config.from_json('config/config.json')
      def from_json(path)
        instance._figi_load(JSON.parse(File.read(path)))
      end

      # Load config from yaml file
      #
      # @param path[String] File path
      # @example
      #   Figi::Config.from_yaml('config/config.yml')
      def from_yaml(path)
        instance._figi_load(YAML.safe_load(File.read(path)))
      end

      # Load config from hash
      #
      # @param config [Hash] Config
      # @example
      #   Figi::Config.load(host: 'localhost', port: '27017')
      #   figi.host
      #   # => localhost
      #
      #   Figi::Config.load do |config|
      #     config.host = 'localhost'
      #     config.port = '27017'
      #   end
      #   figi.host
      #   # => localhost
      def load(config = {}, &block)
        instance._figi_load(config, &block)
      end
    end

    # Constructor
    #
    def initialize
      @table = Hashie::Mash.new
    end

    # Load config from hash, don't use this directly
    #
    # @param config [Hash] Config
    def _figi_load(config = {})
      if @table.nil?
        @table = Hashie::Mash.new(config)
      else
        @table.update(config)
      end

      yield @table if block_given?
    end

    # Dispatch to Hashie::Mash
    #
    def method_missing(mid, *args)
      @table.send(mid, *args)
    end

    def_delegators :@table, :inspect, :to_json, :to_h, :to_yaml, :to_s
  end
end
