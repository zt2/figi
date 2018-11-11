module Figi
  require_relative 'figi/config'
end

module Kernel
  def figi
    Figi::Config.instance
  end
end
