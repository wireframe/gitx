require 'yaml'

module Thegarage
  module Gitx
    class Configuration
      DEFAULT_CONFIG = {
        'aggregate_branches' => %w( staging prototype ),
        'reserved_branches' => %w( HEAD master next_release staging prototype ),
        'taggable_branches' => %w( master staging )
      }
      CONFIG_FILE = '.gitx.yml'

      attr_reader :config

      def initialize(root_dir)
        @config = Thor::CoreExt::HashWithIndifferentAccess.new(DEFAULT_CONFIG)
        config_file_path = File.join(root_dir, CONFIG_FILE)
        if File.exists?(config_file_path)
          @config.merge!(::YAML::load_file(config_file_path))
        end
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
    end
  end
end
