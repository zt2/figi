$LOAD_PATH.unshift(File.expand_path(File.join(__dir__, 'lib')))
require 'figi/version'

Gem::Specification.new do |gem|
  gem.name = 'figi'
  gem.version = Figi::Version.to_s
  gem.date = '2018-11-12'
  gem.authors = ['ztz']
  gem.email = ['hi_ztz@protonmail.com']
  gem.description = 'Figi is a simple and easy ruby config library'
  gem.summary = 'Easy config library'
  gem.homepage = 'https://github.com/zt2/figi'
  gem.license = 'MIT'

  gem.files = `git ls-files`.split
  gem.require_paths = ['lib']
  gem.add_runtime_dependency 'hashie', '~> 3.6'
end
