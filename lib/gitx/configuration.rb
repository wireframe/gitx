require 'yaml'
require 'thor/core_ext/hash_with_indifferent_access'

module Gitx
  class Configuration
    CONFIG_FILE = '.gitx.yml'.freeze

    attr_reader :config

    def initialize(root_dir)
      @config = Thor::CoreExt::HashWithIndifferentAccess.new
      @config.merge!(load_config(File.join(__dir__, 'defaults.yml')))
      @config.merge!(load_config(File.join(root_dir, CONFIG_FILE)))
    end

    def base_branch
      config[:base_branch]
    end

    def release_label
      config[:release_label]
    end

    def aggregate_branches
      config[:aggregate_branches]
    end

    def aggregate_branch?(branch)
      aggregate_branches.include?(branch)
    end

    def reserved_branches
      config[:reserved_branches]
    end

    def reserved_branch?(branch)
      reserved_branches.include?(branch)
    end

    def taggable_branches
      config[:taggable_branches]
    end

    def taggable_branch?(branch)
      taggable_branches.include?(branch)
    end

    def after_release_scripts
      config[:after_release]
    end

    private

    # load configuration file
    def load_config(path)
      if File.exist?(path)
        ::YAML.load_file(path)
      else
        {}
      end
    end
  end
end
