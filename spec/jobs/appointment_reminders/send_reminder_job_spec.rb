require "rails_helper"

RSpec.describe AppointmentReminders::SendReminderJob, type: :job do
  describe "#perform" do

    let(:reminder) { create(:appointment_reminder) }
    let(:notification_service) { double }

    def simulate_successful_delivery
      allow_any_instance_of(NotificationService).to receive(:send_whatsapp).and_return(notification_service)
      allow(notification_service).to receive(:status).and_return("sent")
      allow(notification_service).to receive(:sid).and_return("12345")
    end

    it "sends a whatsapp message when in India" do
      simulate_successful_delivery

      expect_any_instance_of(NotificationService).to receive(:send_whatsapp)
      described_class.perform_async(reminder.id)
      described_class.drain
    end

    it "sends sms when not in India" do
      allow_any_instance_of(NotificationService).to receive(:send_sms).and_return(notification_service)
      allow(notification_service).to receive(:status).and_return("sent")
      allow(notification_service).to receive(:sid).and_return("12345")

      allow(CountryConfig).to receive(:current).and_return(CountryConfig.for(:BD))
      expect_any_instance_of(NotificationService).to receive(:send_sms)
      described_class.perform_async(reminder.id)
      described_class.drain
    end

    it "creates a communication with twilio response status and sid" do
      simulate_successful_delivery

      expect(Communication).to receive(:create_with_twilio_details!).with(
        appointment: reminder.appointment,
        twilio_sid: "12345",
        twilio_msg_status: "sent",
        communication_type: "missed_visit_whatsapp_reminder"
      ).and_call_original
      expect {
        described_class.perform_async(reminder.id)
        described_class.drain
      }.not_to raise_error
    end

    it "selects the message language based on patient address" do
      simulate_successful_delivery
      reminder.patient.address.update(state: "punjab")
      localized_message = I18n.t(
        reminder.message,
        {
          appointment_date: reminder.appointment.scheduled_date,
          assigned_facility_name: reminder.appointment.facility.name,
          patient_name: reminder.patient.full_name,
          locale: "pa-Guru-IN"
        }
      )

      expect_any_instance_of(NotificationService).to receive(:send_whatsapp).with(
        reminder.patient.latest_mobile_number,
        localized_message,
        "https://localhost/api/v3/twilio_sms_delivery"
      )
      described_class.perform_async(reminder.id)
      described_class.drain
    end

    it "defaults to english if the patient does not have an address" do
      simulate_successful_delivery
      reminder.patient.update!(address_id: nil)
      localized_message = I18n.t(
        reminder.message,
        {
          appointment_date: reminder.appointment.scheduled_date,
          assigned_facility_name: reminder.appointment.facility.name,
          patient_name: reminder.patient.full_name,
          locale: "en"
        }
      )

      expect_any_instance_of(NotificationService).to receive(:send_whatsapp).with(
        reminder.patient.latest_mobile_number,
        localized_message,
        "https://localhost/api/v3/twilio_sms_delivery"
      )
      described_class.perform_async(reminder.id)
      described_class.drain
    end
  end
end