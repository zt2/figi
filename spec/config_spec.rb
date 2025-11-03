# frozen_string_literal: true

require 'tmpdir'
require 'fileutils'
require 'json'
require 'yaml'

RSpec.describe Figi::Config do
  before do
    Figi::Config.reset!
  end

  describe 'defaults and aliases' do
    it 'applies defaults, aliases and typed getters' do
      Figi::Config.register_defaults('database.host' => 'localhost', database: { port: 5432 })
      Figi::Config.register_defaults('feature.enabled' => true)
      Figi::Config.register_alias('db_host', 'database.host')
      Figi::Config.register_alias(:db_port, 'database.port')

      Figi::Config.load(read_files: false, read_env: false, read_remote: false) do |cfg|
        cfg.db_host = 'db.internal'
        cfg.database.port = '5433'
        cfg.database.tags = %w[primary analytics]
      end

      expect(Figi::Config.get_string('database.host')).to eq('db.internal')
      expect(Figi::Config.get_string('db_host')).to eq('db.internal')
      expect(Figi::Config.get_int('database.port')).to eq(5433)
      expect(Figi::Config.get_int(:db_port)).to eq(5433)
      expect(Figi::Config.get_bool('feature.enabled')).to eq(true)
      expect(Figi::Config.get_array('database.tags')).to eq(%w[primary analytics])
      expect(Figi::Config.get_hash('database')['tags']).to eq(%w[primary analytics])
    end
  end

  describe 'config file discovery' do
    it 'loads JSON, YAML and TOML files from configured paths' do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, 'app.json'), { 'service' => { 'name' => 'json' } }.to_json)
        File.write(File.join(dir, 'app.yaml'), { 'service' => { 'port' => 8080 } }.to_yaml)
        File.write(File.join(dir, 'app.toml'), "[service]\nenabled = true\n")

        Figi::Config.set_config_name('app')
        Figi::Config.add_config_path(dir)
        Figi::Config.read_in_config

        expect(Figi::Config.get_string('service.name')).to eq('json')
        expect(Figi::Config.get_int('service.port')).to eq(8080)
        expect(Figi::Config.get_bool('service.enabled')).to eq(true)
      end
    end
  end

  describe 'environment binding' do
    it 'loads environment variables using prefix and type coercion' do
      begin
        ENV['FIGI_SERVICE_URL'] = 'https://example.test'
        ENV['FIGI_SERVICE_ENABLED'] = 'true'

        Figi::Config.load(read_files: false, read_remote: false, read_env: true)

        expect(Figi::Config.get_string('service.url')).to eq('https://example.test')
        expect(Figi::Config.get_bool('service.enabled')).to eq(true)
      ensure
        ENV.delete('FIGI_SERVICE_URL')
        ENV.delete('FIGI_SERVICE_ENABLED')
      end
    end

    it 'supports manual bindings and custom key formatting' do
      begin
        Figi::Config.configure_env(prefix: 'APP', separator: '__') do |binding|
          binding.set_formatter { |segments| segments.map(&:downcase).join('.') }
        end
        Figi::Config.bind_env('APP__SERVICE__TIMEOUT', 'service.timeout') { |value| value.to_i * 2 }
        ENV['APP__SERVICE__TIMEOUT'] = '15'

        Figi::Config.load(read_files: false, read_remote: false, read_env: true)

        expect(Figi::Config.get_int('service.timeout')).to eq(30)
      ensure
        ENV.delete('APP__SERVICE__TIMEOUT')
      end
    end
  end

  describe 'source priority' do
    it 'applies priority defaults < files < remote < env < cli' do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, 'config.json'), { 'feature' => { 'flag' => 'file' } }.to_json)

        Figi::Config.register_defaults('feature.flag' => 'default')
        Figi::Config.set_config_name('config')
        Figi::Config.add_config_path(dir)

        remote_payload = { 'feature' => { 'flag' => 'remote' } }
        Figi::Config.register_remote_source(:memory) { remote_payload }

        begin
          ENV['FIGI_FEATURE_FLAG'] = 'env'

          Figi::Config.load({ feature: { flag: 'cli' } }, read_files: true, read_env: true, read_remote: true)
          expect(Figi::Config.get_string('feature.flag')).to eq('cli')

          Figi::Config.load({}, read_files: false, read_env: true, read_remote: false)
          expect(Figi::Config.get_string('feature.flag')).to eq('env')

          ENV.delete('FIGI_FEATURE_FLAG')
          Figi::Config.load({}, read_files: false, read_env: true, read_remote: true)
          expect(Figi::Config.get_string('feature.flag')).to eq('remote')

          remote_payload.replace('feature' => { 'flag' => 'remote2' })
          Figi::Config.refresh_remote_source(:memory)
          expect(Figi::Config.get_string('feature.flag')).to eq('remote2')
        ensure
          ENV.delete('FIGI_FEATURE_FLAG')
        end
      end
    end
  end

  describe 'file watching and callbacks' do
    it 'reloads configuration files and triggers callbacks' do
      Dir.mktmpdir do |dir|
        path = File.join(dir, 'config.json')
        File.write(path, { 'service' => { 'name' => 'initial' } }.to_json)

        changes = []
        Figi::Config.on_change { |config| changes << config.to_h }

        Figi::Config.set_config_name('config')
        Figi::Config.add_config_path(dir)
        Figi::Config.load({}, read_files: true, watch_files: true, read_env: false, read_remote: false)

        expect(Figi::Config.get_string('service.name')).to eq('initial')

        File.write(path, { 'service' => { 'name' => 'updated' } }.to_json)
        Figi::Config.simulate_file_change(path)

        expect(Figi::Config.get_string('service.name')).to eq('updated')
        expect(changes.last['service']['name']).to eq('updated')
      end
    end
  end

  describe 'error handling' do
    it 'raises when file missing' do
      expect { Figi::Config.from_json('/no/such/file.json') }.to raise_error(Figi::ConfigFileNotFoundError)
    end

    it 'raises when parsing fails' do
      Dir.mktmpdir do |dir|
        path = File.join(dir, 'invalid.json')
        File.write(path, '{ invalid json }')

        expect { Figi::Config.from_json(path) }.to raise_error(Figi::ConfigParseError)
      end
    end

    it 'raises when type coercion fails' do
      Figi::Config.load({ feature: { flag: 'maybe' } }, read_files: false, read_env: false, read_remote: false)
      expect { Figi::Config.get_bool('feature.flag') }.to raise_error(Figi::ConfigTypeError)
    end
  end
end
