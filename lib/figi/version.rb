module Figi
  #
  # Version
  #
  module Version
    MAJOR = '0'.freeze
    MINOR = '1'.freeze
    PATCH = '0'.freeze

    class << self
      def to_s
        "#{MAJOR}.#{MINOR}.#{PATCH}"
      end
    end
  end
end
