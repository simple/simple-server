require "rails_helper"

RSpec.describe Seed::ProductionExperimentTestSeeder do
  it "creates experiment, treatment groups, and reminder templates" do
    facility = create(:facility)
    user = create(:user, registration_facility: facility)

    expect(Experimentation::Experiment.count).to eq(0)
    expect(Experimentation::TreatmentGroup.count).to eq(0)
    expect(Experimentation::ReminderTemplate.count).to eq(0)
    described_class.call(days_till_start: 1, user_id: user.id)
    expect(Experimentation::Experiment.count).to eq(1)
    expect(Experimentation::TreatmentGroup.count).to eq(3)
    expect(Experimentation::ReminderTemplate.count).to eq(3)
  end
end
