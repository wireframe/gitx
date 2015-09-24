require 'gitx/executor'

RSpec.describe Gitx::Executor do
  let(:executor) { described_class.new }
  let(:exit_value) { double(:exit_value, success?: true) }
  let(:thread) { double(:thread, value: exit_value) }
  let(:stdoutput) { StringIO.new('Hello World') }
  before do
    expect(Open3).to receive(:popen2e).and_yield(nil, stdoutput, thread)
  end

  describe '#execute' do
    context 'when execution is successful and block given' do
      before do
        @output = []
        executor.execute('some', 'command', '--with', '--args') do |output|
          @output << output
        end
      end
      it 'yields the command and output' do
        expect(@output).to eq ['$ some command --with --args', 'Hello World']
      end
    end
    context 'when execution is successful' do
      before do
        @output = executor.execute('some', 'command', '--with', '--args')
      end
      it 'returns the output' do
        expect(@output).to eq 'Hello World'
      end
    end
    context 'when execution is not sucessful' do
      let(:exit_value) { double(:exit_value, success?: false) }
      it 'raises ExecutionError' do
        expect do
          executor.execute('some', 'bad', 'command')
        end.to raise_error Gitx::Executor::ExecutionError
      end
    end
  end
end
