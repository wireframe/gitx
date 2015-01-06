require 'spec_helper'
require 'thegarage/gitx/cli/start_command'

describe Thegarage::Gitx::Cli::BaseCommand do
  let(:args) { [] }
  let(:options) { {} }
  let(:config) do
    {
      pretend: true
    }
  end
  let(:cli) { Thegarage::Gitx::Cli::StartCommand.new(args, options, config) }

  describe 'with default configuration' do
    it 'provides deafault options' do
      expect(cli.send(:config)[:aggregate_branches]).to eq(%w( staging prototype ))
      expect(cli.send(:config)[:reserved_branches]).to eq(%w( HEAD master next_release staging prototype ))
      expect(cli.send(:config)[:taggable_branches]).to eq(%w( master staging ))
    end
  end

  describe 'with custom configuration' do
    before(:each) do
      File.open(".git_workflow", "w") do |f|
        f.puts "aggregate_branches:\n  - foo\n  - bar"
        f.puts "reserved_branches:\n  - baz\n  - qux"
        f.puts "taggable_branches:\n  - quux\n  - corge"
      end
    end
    after(:each) { FileUtils.rm_f '.git_workflow' }

    it 'overrides default options' do
      expect(cli.send(:config)[:aggregate_branches]).to eq(%w( foo bar ))
      expect(cli.send(:config)[:reserved_branches]).to eq(%w( baz qux ))
      expect(cli.send(:config)[:taggable_branches]).to eq(%w( quux corge ))
    end
  end
end