# empty matcher to allow for mock expectations to fire
RSpec::Matchers.define :meet_expectations do |_expected|
  match do |_actual|
    # do nothing
    expect(true).to be true
  end
end
