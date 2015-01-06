require 'spec_helper'
require 'thegarage/gitx/cli/base_command'

describe Thegarage::Gitx::Cli::BaseCommand do
  let(:args) { [] }
  let(:options) { {} }
  let(:config) do
    {
      pretend: true
    }
  end
  let(:cli) { described_class.new(args, options, config) }
  let(:repo) { cli.send(:repo) }

  describe 'without custom .gitx.yml config file' do
    it 'provides default options' do
      expect(cli.send(:config).config).to eq Thegarage::Gitx::Configuration::DEFAULT_CONFIG
    end
  end

  describe 'with custom .gitx.yml config file' do
    let(:config) do
      {
        'aggregate_branches' => %w( foo bar ),
        'reserved_branches' => %w( baz qux ),
        'taggable_branches' => %w( quux corge )
      }
    end
    before do
      expect(repo).to receive(:workdir).and_return(temp_dir)
      File.open(File.join(temp_dir, '.gitx.yml'), 'w') do |f|
        f.puts config.to_yaml
      end
    end
    it 'overrides default options' do
      expect(cli.send(:config).aggregate_branches).to eq(%w( foo bar ))
      expect(cli.send(:config).reserved_branches).to eq(%w( baz qux ))
      expect(cli.send(:config).taggable_branches).to eq(%w( quux corge ))
    end
  end
end
