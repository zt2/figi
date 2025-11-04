# frozen_string_literal: true

unless defined?(Listen)
  module Listen
    class Listener
      def initialize(*_paths, &callback)
        @callback = callback
      end

      def start; end

      def stop; end

      def trigger(modified = [], added = [], removed = [])
        @callback&.call(modified, added, removed)
      end
    end

    def self.to(*paths, &block)
      Listener.new(*paths, &block)
    end
  end
end
