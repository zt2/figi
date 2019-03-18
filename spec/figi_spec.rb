RSpec.describe Figi do
  it "has a version number" do
    expect(Figi::Version).not_to be nil
  end

  it "support load configuration from json file" do
    json_file = File.expand_path(File.join('test_data', 'config.json'), __dir__)
    json_dat = JSON.parse(File.read(json_file))
    expect { Figi::Config.from_json(json_file) }.not_to raise_error
    expect(figi.to_h).to eq(json_dat)
  end

  it "support load configuration from yaml file" do
    yml_file = File.expand_path(File.join('test_data', 'config.json'), __dir__)
    yml_dat = YAML.safe_load(File.read(yml_file))
    expect { Figi::Config.from_yaml(yml_file) }.not_to raise_error
    expect(figi.to_h).to eq(yml_dat)
  end

  it "support method access" do
    figi.host = 'localhost'
    expect(figi.host).to eq('localhost')
    expect(figi.host?).to eq(true)
    expect(figi.non_exists?).to eq(false)
  end

  it "support load from args" do
    Figi::Config.load(environment: 'production', username: 'root')
    expect(figi.environment).to eq('production')
    expect(figi.username).to eq('root')
  end

  it "support config with dsl" do
    Figi::Config.load do |config|
      config.environment = 'production'
      config.username = 'root'
    end
    expect(figi.environment).to eq('production')
    expect(figi.username).to eq('root')
  end

  it "support nested access" do
    figi.db = {
        host: 'localhost',
        port: 27017
    }
    expect(figi.db.host).to eq('localhost')
    expect(figi.db.port).to eq(27017)
  end
end
