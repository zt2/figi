#
# Figi base module
#
module Figi
  require_relative 'figi/config'
  require_relative 'figi/version'
end

#
# Support global access
#
module Kernel
  def figi
    Figi::Config.instance
  end
end
