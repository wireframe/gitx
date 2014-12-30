# helper for reading global config file
module GlobalConfig
  def global_config_file
    config_dir = File.join(__dir__, '../tmp/.config/gitx')
    config_file = File.join(config_dir, 'github.yml')
    FileUtils.mkdir_p(config_dir) unless File.exists?(config_dir)
    config_file
  end
  def global_config
    YAML.load_file(global_config_file)
  end
end

RSpec.configure do |config|
  config.include GlobalConfig

  config.before do
    tmp_dir = File.join(__dir__, '../tmp')
    FileUtils.rm_rf(tmp_dir)
  end
end
