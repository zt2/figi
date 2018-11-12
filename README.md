# FIGI

FIGI is a super simple configuration library you can use in your ruby application.

## Install

```
gem install figi
```

## Usage

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

- Support JSON and YAML file

```ruby
require 'figi'

Figi::Config.from_json('config/config.json')
Figi::Config.from_yaml('config/config.yml')

puts figi.environment
# => development
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