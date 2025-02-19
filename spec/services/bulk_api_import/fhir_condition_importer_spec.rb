require "rails_helper"

RSpec.describe BulkApiImport::FhirConditionImporter do
  before { create(:facility) }
  let(:import_user) { ImportUser.find_or_create }
  let(:identifier) { SecureRandom.uuid }
  let(:patient) { build_stubbed(:patient, id: Digest::UUID.uuid_v5(Digest::UUID::DNS_NAMESPACE, identifier)) }
  let(:patient_identifier) do
    build_stubbed(:patient_business_identifier, patient: patient,
                  identifier: identifier,
                  identifier_type: :external_import_id)
  end

  describe "#import" do
    it "imports a medication request" do
      identifier = patient_identifier.identifier
      expect {
        described_class.new(
          build_condition_import_resource.merge(subject: {identifier: identifier})
        ).import
      }.to change(MedicalHistory, :count).by(1)
    end
  end

  describe "#build_attributes" do
    it "correctly builds valid attributes across different blood pressure resources" do
      10.times.map { build_condition_import_resource }.each do |resource|
        condition_resource = resource.merge(subject: {identifier: patient_identifier.identifier})

        attributes = described_class.new(condition_resource).build_attributes

        expect(Api::V3::MedicalHistoryPayloadValidator.new(attributes)).to be_valid
        expect(attributes[:patient_id]).to eq(patient.id)
      end
    end
  end

  describe "#diagnoses" do
    it "extracts diagnoses for diabetes and hypertension" do
      [
        {coding: [], expected: {hypertension: "no", diabetes: "no"}},
        {coding: [{code: "38341003"}], expected: {hypertension: "yes", diabetes: "no"}},
        {coding: [{code: "73211009"}], expected: {hypertension: "no", diabetes: "yes"}},
        {coding: [{code: "38341003"}, {code: "73211009"}], expected: {hypertension: "yes", diabetes: "yes"}}
      ].each do |coding:, expected:|
        expect(described_class.new({code: {coding: coding}}).diagnoses)
          .to eq(expected)
      end
    end
  end
end
