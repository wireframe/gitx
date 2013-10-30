# empty matcher to allow for mock expectations to fire
RSpec::Matchers.define :meet_expectations do |expected|
  match do |actual|
    # do nothing
    expect(true).to be_true
  end
end
