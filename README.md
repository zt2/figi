# Figi

Figi is a lightweight configuration toolkit for Ruby applications. It layers
configuration from defaults, files, remote providers, environment variables and
runtime overrides into a single `Hashie::Mash` so you can read settings with a
natural, Ruby-ish API.

## Highlights

* **Ruby 3 first.** Requires Ruby 3.1+ and embraces modern language features.
* **Multiple sources.** Merge defaults, JSON/YAML/TOML files, environment
  variables, remote backends and direct overrides in a deterministic order.
* **Ergonomic access.** Work with `figi.database.host`, `figi[:database][:host]`
  or typed getters such as `get_bool` and `get_int`.
* **Live updates.** Opt-in file watching and remote polling refresh the merged
  configuration and notify registered callbacks.
* **Customisable environment bindings.** Define prefixes, separators and manual
  bindings to translate environment variables into nested config keys.

## Installation

Add Figi to your application's Gemfile:

```ruby
gem 'figi'
```

Install the dependency:

```bash
bundle install
```

or grab it directly:

```bash
gem install figi
```

## Quick start

```ruby
require 'figi'

# Provide defaults for missing values.
Figi::Config.register_defaults do |defaults|
  defaults.environment = 'development'
  defaults.database.host = 'localhost'
end

# Load files from ./config/config.yml (YAML, JSON and TOML supported).
Figi::Config.add_config_path('config')
Figi::Config.set_config_name('config')
Figi::Config.read_in_config

# Optionally merge environment variables such as FIGI_DATABASE__PASSWORD.
Figi::Config.configure_env(separator: '__')
Figi::Config.load_env

# Inject overrides from the current process.
Figi::Config.load(environment: 'production')

figi = Figi::Config.instance
puts figi.environment          #=> "production"
puts figi.database.host        #=> "localhost"
puts figi.get_string('app.name', 'MyApp')
```

## Loading configuration

### Defaults

Register default values with a block or hash. They are merged first and provide
structure for the rest of the sources.

```ruby
Figi::Config.register_defaults(
  'logging.level' => 'info',
  'features.cache' => true
)
```

### Files

By default Figi searches the current working directory for `config.json`,
`config.yml`, `config.yaml` or `config.toml`. You can point it to additional
paths or filenames:

```ruby
Figi::Config.add_config_path('/etc/my-app')
Figi::Config.set_config_name('settings')
Figi::Config.read_in_config
```

Pass `watch: true` to `read_in_config` to enable file watching (requires the
`listen` gem). When files change, Figi reloads them and re-merges the table.

### Environment variables

Environment bindings translate keys such as `FIGI_DATABASE__HOST` into nested
values. Customise the prefix, separator, formatting and manual mappings:

```ruby
Figi::Config.configure_env(prefix: 'MY_APP', separator: '__') do |env|
  env.set_formatter { |segments| segments.map(&:downcase).join('.') }
  env.bind('LEGACY_TIMEOUT', 'http.timeout') { |value| Integer(value) }
end

Figi::Config.load_env
```

### Remote sources

Integrate with arbitrary remote providers by registering a loader block. The
loader should return a hash-like object and may raise `Figi::ConfigRemoteError`
for recoverable issues.

```ruby
Figi::Config.register_remote_source(:vault, interval: 30) do
  JSON.parse(HTTP.get('https://example.com/config').to_s)
end

Figi::Config.start_remote_sources
```

Call `refresh_remote_source(:vault)` to trigger an immediate poll or
`stop_remote_sources` to halt background threads.

### Runtime overrides

`Figi::Config.load` accepts either a hash or a block that mutates a
`Hashie::Mash`. These overrides sit at the highest precedence in the merge
order.

```ruby
Figi::Config.load do |config|
  config.features.beta = true
end
```

## Working with values

* Use method access (`figi.cache.enabled`) or hash access (`figi['cache']['enabled']`).
* Typed helpers (`get_bool`, `get_int`, `get_float`, `get_array`, `get_hash`) raise
  `Figi::ConfigTypeError` when the stored value cannot be coerced.
* Register callbacks with `on_change` to react to live updates from file
  watchers or remote sources.

## Development

Clone the repository and install dependencies:

```bash
git clone https://github.com/zt2/figi.git
cd figi
bundle install
```

Run the test suite:

```bash
bundle exec rspec
```

Pull requests and bug reports are welcome! The project is released under the
[MIT License](LICENSE).
