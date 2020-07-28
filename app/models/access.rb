class Access < ApplicationRecord
  ALLOWED_SCOPES = %w[Organization FacilityGroup Facility].freeze

  belongs_to :user
  belongs_to :resource, polymorphic: true

  enum mode: {
    viewer: "viewer",
    manager: "manager",
    super_admin: "super_admin"
  }

  validates :mode, presence: true
  validates :user, uniqueness: {scope: [:resource_id, :resource_type], message: "can only have one access per resource."}
  validates :resource, presence: {unless: :super_admin?, message: "is required if not a super_admin."}
  validates :resource, inclusion: {in: [nil], if: :super_admin?, message: "must be nil if super_admin"}
  validates :resource_type, inclusion: {in: ALLOWED_SCOPES, unless: :super_admin?}

  class << self
    def organizations(action)
      scope_for(Organization, action)
    end

    def facility_groups(action)
      scope_for(FacilityGroup, action)
        .or(FacilityGroup.where(organization: organizations(action)))
    end

    def facilities(action)
      scope_for(Facility, action)
        .or(Facility.where(facility_group: facility_groups(action)))
    end

    private

    def modes_for(action)
      case action
        when :view
          [:manager, :viewer]
        when :manage
          [:manager]
        else
          raise ArgumentError, "Invalid action: #{action}"
      end
    end

    def scope_for(scope, action)
      return scope.all if super_admin?
      scope.where(id: where(scope_type: scope.to_s, mode: modes_for(action)).pluck(:scope_id))
    end
  end
end
