# helper for reading global config file
module GlobalConfig
  def global_config_file
    config_file = File.join(temp_dir, '.config/gitx/github.yml')
    config_dir = File.dirname(config_file)
    FileUtils.mkdir_p(config_dir) unless File.exists?(config_dir)
    config_file
  end
  def global_config
    YAML.load_file(global_config_file)
  end
  def temp_dir
    tmp_dir = File.join(__dir__, '../tmp')
  end
end

RSpec.configure do |config|
  config.include GlobalConfig

  config.before do
    FileUtils.rm_rf(temp_dir)
    FileUtils.mkdir_p(temp_dir)
  end
end
