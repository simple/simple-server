module Experimentation
  class Experiment < ActiveRecord::Base
    has_many :treatment_cohorts

    validates :lookup_name, presence: true, uniqueness: true
    validates :state, presence: true
    validates :experiment_type, presence: true

    enum state: [:inactive, :active_selection, :active_preselected], _prefix: true
    enum experiment_type: [:current_patient_reminder, :stale_patient_reminder], _prefix: true
  end
end
