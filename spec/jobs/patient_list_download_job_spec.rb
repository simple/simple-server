require "rails_helper"
require "sidekiq_unique_jobs/testing"

RSpec.describe PatientListDownloadJob, type: :job do
  let!(:admin) { create(:admin) }
  let!(:facility) { create(:facility, enable_diabetes_management: true) }
  let!(:other_facility) { create(:facility, enable_diabetes_management: true) }
  let!(:assigned_patients) { create_list(:patient, 2, assigned_facility: facility) }
  let!(:registered_patients) { create_list(:patient, 2, registration_facility: facility, assigned_facility: other_facility) }

  specify { expect(described_class).to have_valid_sidekiq_options }

  it "should work for FacilityGroup" do
    facility_group = create(:facility_group)
    facility = create(:facility, facility_group: facility_group, enable_diabetes_management: true)
    patient = create_list(:patient, 2, assigned_facility: facility)
    expect(PatientsWithHistoryExporter).to receive(:csv)
      .with(a_collection_containing_exactly(*patient), {display_blood_sugars: true})
    described_class.perform_async(admin.email, "facility_group", {id: facility_group.id})
    described_class.drain
  end

  it "should queue a PatientsWithHistoryExporter export" do
    expect(PatientsWithHistoryExporter).to receive(:csv)
    described_class.perform_async(admin.email, "facility", {facility_id: facility.id})
    described_class.drain
  end

  it "should not display blood sugars if diabetes management is disabled for a facility" do
    facility.update(enable_diabetes_management: false)
    expect(PatientsWithHistoryExporter).to receive(:csv)
      .with(Patient.where(id: assigned_patients), {display_blood_sugars: false})
    described_class.perform_async(admin.email, "facility", {facility_id: facility.id})
    described_class.drain
  end

  context "facilities" do
    it "should export only assigned patients" do
      expect(PatientsWithHistoryExporter).to receive(:csv)
        .with(Patient.where(id: assigned_patients), {display_blood_sugars: true})
      described_class.perform_async(admin.email, "facility", {facility_id: facility.id})
      described_class.drain
    end
  end
end
