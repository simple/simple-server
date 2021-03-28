require "rails_helper"

RSpec.describe Experimentation::Experiment, type: :model do
  let(:experiment) { create(:experiment) }

  describe "associations" do
    it { should have_many(:treatment_cohorts) }
  end

  describe "validations" do
    it { should validate_presence_of(:lookup_name) }
    it { experiment.should validate_uniqueness_of(:lookup_name) }
    it { should validate_presence_of(:state) }
    it { should validate_presence_of(:experiment_type) }
  end
end
