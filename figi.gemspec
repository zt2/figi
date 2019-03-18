lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'figi/version'

Gem::Specification.new do |gem|
  gem.name          = 'figi'
  gem.version       = Figi::Version.to_s
  gem.authors       = ['ztz']
  gem.email         = ['hi_ztz@protonmail.com']

  gem.summary       = 'Easy config library'
  gem.description   = 'Figi is a simple and easy ruby config library'
  gem.homepage      = 'https://github.com/zt2/figi'
  gem.license       = 'MIT'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gem.files         = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end

  gem.require_paths = ['lib']

  gem.add_development_dependency 'bundler', '~> 2.0'
  gem.add_development_dependency 'rake', '~> 10.0'
  gem.add_development_dependency 'rspec', '~> 3.0'

  gem.add_runtime_dependency 'hashie', '~> 3.6'
end
