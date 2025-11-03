module Figi
  #
  # Version
  #
  module Version
    extend self

    MAJOR = 0
    MINOR = 1
    PATCH = 1

    def to_s = [MAJOR, MINOR, PATCH].join('.')
  end
end
