require "tzinfo"
require File.expand_path("../config/environment", __dir__)

set :output, "/home/deploy/apps/simple-server/shared/log/cron.log"

env :PATH, ENV["PATH"]
DEFAULT_CRON_TIME_ZONE = "Asia/Kolkata"

def local(time)
  TZInfo::Timezone.get(Rails.application.config.country[:time_zone] || DEFAULT_CRON_TIME_ZONE)
    .local_to_utc(Time.parse(time))
end

FOLLOW_UP_TIMES = [
  "08:00 am",
  "08:30 am",
  "09:00 am",
  "09:30 am",
  "10:00 am",
  "10:30 am",
  "11:00 am",
  "12:00 pm",
  "12:30 pm",
  "01:00 pm",
  "01:30 pm",
  "02:00 pm",
  "02:30 pm",
  "03:00 pm",
  "03:30 pm",
  "04:00 pm",
  "04:30 pm",
  "05:00 pm",
  "05:30 pm",
  "06:00 pm",
  "06:30 pm",
  "07:00 pm"
].map { |t| local(t) }

REPORTS_REFRESH_FREQUENCY = CountryConfig.current_country?("India") ? :saturday : :day
REPORTS_REFRESH_TIME = CountryConfig.current_country?("India") ? "05:00 pm" : "12:30 am"
REPORTS_CACHE_REFRESH_TIME = CountryConfig.current_country?("India") ? "11:55 pm" : "04:30 am"

every :day, at: FOLLOW_UP_TIMES, roles: [:cron] do
  rake "db:refresh_daily_follow_ups_and_registrations"
end

every :day, at: local("02:00 pm"), roles: [:cron] do
  if CountryConfig.current_country?("India") && SimpleServer.env.production?
    rake "bsnl:alert_on_low_balance"
  end
end

every :day, at: local("05:30 pm"), roles: [:cron] do
  runner "Messaging::Bsnl::Sms.get_message_statuses"
end

every :day, at: local("05:30 pm"), roles: [:cron] do
  runner "Messaging::AlphaSms::Sms.get_message_statuses"
end

every :day, at: local("11:00 pm").utc, roles: [:cron] do
  rake "appointment_notification:three_days_after_missed_visit"
end

every :day, at: local("11:00 pm"), roles: [:cron] do
  runner "Messaging::Bsnl::Sms.get_message_statuses"
end

every :day, at: local("11:45 pm"), roles: [:sidekiq] do
  command "systemctl restart sidekiq --user"
end

every :day, at: local("12:00 am"), roles: [:whitelist_phone_numbers] do
  rake "exotel_tasks:whitelist_patient_phone_numbers"
end

every REPORTS_REFRESH_FREQUENCY, at: local(REPORTS_REFRESH_TIME), roles: [:cron] do
  rake "db:refresh_reporting_views"
end

every :week, at: local("01:00 am"), roles: [:whitelist_phone_numbers] do
  rake "exotel_tasks:update_all_patients_phone_number_details"
end

every :day, at: local("01:00 am"), roles: [:cron] do
  runner "MarkPatientMobileNumbers.call"
end

every :week, at: local("01:00 am"), roles: [:cron] do
  if CountryConfig.current_country?("India") && SimpleServer.env.production?
    rake "bsnl:refresh_sms_jwt"
  end
end

every :day, at: local("02:00 am"), roles: [:cron] do
  runner "PatientDeduplication::Runner.new(PatientDeduplication::Strategies.identifier_and_full_name_match).call"
end

every :day, at: local("02:30 am"), roles: [:cron] do
  runner "RecordCounterJob.perform_async"
end

every REPORTS_REFRESH_FREQUENCY, at: local(REPORTS_CACHE_REFRESH_TIME), roles: [:cron] do
  runner "Reports::RegionCacheWarmer.call"
end

every 1.month, at: local("04:00 am"), roles: [:cron] do
  if Flipper.enabled?(:dhis2_export)
    rake "dhis2:export"
  end
end

every 1.month, at: local("04:15 am"), roles: [:cron] do
  if Flipper.enabled?(:bangladesh_disaggregated_dhis2_export)
    rake "dhis2:bangladesh_disaggregated_export"
  end
end

every 1.month, at: local("04:15 am"), roles: [:cron] do
  if Flipper.enabled?(:ethiopia_dhis2_export)
    rake "dhis2:ethiopia_export"
  end
end

every :day, at: local("05:00 am"), roles: [:cron] do
  runner "DuplicatePassportAnalytics.call"
end

every :day, at: local("05:45 am"), roles: [:cron] do
  rake "experiments:conduct_daily"
end

every 1.month, at: local("06:00 am"), roles: [:cron] do
  rake "questionnaires:initialize"
end

every 1.month, at: local("07:00 am"), roles: [:cron] do
  if Flipper.enabled?(:automated_telemed_report)
    rake "reports:telemedicine"
  end
end

every 2.minutes, roles: [:cron] do
  runner "TracerJob.perform_async(Time.current.iso8601, false)"
end

every 30.minutes, roles: [:cron] do
  runner "RegionsIntegrityCheck.call"
end
