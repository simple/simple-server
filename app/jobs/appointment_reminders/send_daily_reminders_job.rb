class AppointmentReminders::SendDailyRemindersJob < ApplicationJob
  queue_as :high

  def perform
    # add feature flag?
    # given that the cron runs in the middle of the night, i would imagine this will always
    # result in messages being sent the same day, but we will need to be certain of that
    # either by carefully scheduling the cron or by moving away from next_messaging_time
    next_messaging_time = Communication.next_messaging_time
    reminders = AppointmentReminder.where(remind_on: Date.current).pluck(:id)
    reminders.each do |reminder|
      AppointmentReminders::SendReminderJob.perform_at(next_messaging_time, reminder)
    end
  end
end