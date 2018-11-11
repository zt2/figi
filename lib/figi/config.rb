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
  class Config
    extend Forwardable
    include Singleton

    class << self
      def from_json(path)
        instance._figi_load(JSON.parse(File.read(path)))
      end

      def from_yaml(path)
        instance._figi_load(YAML.safe_load(File.read(path)))
      end

      def load(config = nil, &block)
        instance._figi_load(config, &block)
      end
    end

    def initialize
      @table = Hashie::Mash.new
    end

    def _figi_load(config = nil)
      if @table.nil?
        @table = Hashie::Mash.new(config)
      else
        @table.update(config)
      end
      
      yield @table if block_given?
    end

    def method_missing(mid, *args)
      @table.send(mid, *args)
    end

    def_delegators :@table, :inspect, :to_json, :to_h, :to_yaml, :to_s
  end
end
