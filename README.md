# FIGI [![Build Status](https://travis-ci.org/zt2/figi.svg?branch=master)](https://travis-ci.org/zt2/figi) [![Known Vulnerabilities](https://snyk.io/test/github/zt2/figi/badge.svg?targetFile=Gemfile.lock)](https://snyk.io/test/github/zt2/figi?targetFile=Gemfile.lock)

FIGI is a super simple configuration library you can use in your ruby application.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'figi'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install test

## Usage

- Support JSON and YAML file

```ruby
require 'figi'

Figi::Config.from_json('config/config.json')
Figi::Config.from_yaml('config/config.yml')

puts figi.environment
# => development
```

- Method access

```ruby
require 'figi'

figi.host = 'localhost'
puts figi.host
# => localhost

puts figi.host?
# => true
 
puts figi.not_exists?
# => false 
```

- Config once, use everywhere

```ruby
require 'figi'

Figi::Config.load(environment: 'production', username: 'root')

puts figi.environment
# => production
puts figi.username
# => root
```

- Config with DSL

```ruby
Figi::Config.load do |config|
  config.environment = 'production'
  config.username = 'root'
end

puts figi.environment
# => production
```

- Nested method access

```ruby
# nested access
figi.db = {
  host: 'localhost',
  port: 27017
}
puts(figi.db.host) # => localhost
puts(figi.db.port) # => 27017
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/zt2/figi.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
