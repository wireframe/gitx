require 'timecop'

# use safe mode to prevent unexpected time leaking errors
# see https://github.com/travisjeffery/timecop#timecopsafe_mode
RSpec.configure do |config|
  config.before do
    Timecop.safe_mode = true
  end
end
