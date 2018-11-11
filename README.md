# FIGI

FIGI is a super simple configuration library you can use in your ruby application.

```ruby
require 'figi'

# config once
Figi::Config.load(environment: 'production', username: 'root')

# then use everywhere
puts(figi.environment) # => production
puts(figi.username) # => root

# also support loading from json or yaml file
Figi::Config.from_json('config/config.json')
Figi::Config.from_yaml('config/config.yml')

figi.environment = 'development'
puts(figi.environment) # => development

# nested access
figi.db = {
  host: 'localhost',
  port: 27017
}
puts(figi.db.host) # => localhost
puts(figi.db.port) # => 27017
```