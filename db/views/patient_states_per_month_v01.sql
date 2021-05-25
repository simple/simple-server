SELECT
    DISTINCT ON (p.id, month_date)
    ------------------------------------------------------------
    -- basic patient identifiers
    p.id,
    p.status,
    p.gender,
    p.age,
    p.age_updated_at,
    p.date_of_birth,
    p.deleted_at,
    mh.hypertension as hypertension,

    ------------------------------------------------------------
    -- data for the month of
    cal.month,
    cal.year,
    cal.month_date,
    cal.month_string,

    ------------------------------------------------------------
    -- information on assigned facility and parent regions
    p.assigned_facility_id AS patient_assigned_facility_id,
    assigned_facility.facility_slug as assigned_facility_slug,
    assigned_facility.facility_region_id as assigned_facility_region_id,
    assigned_facility.block_slug as assigned_block_slug,
    assigned_facility.block_region_id as assigned_block_region_id,
    assigned_facility.district_slug as assigned_district_slug,
    assigned_facility.district_region_id as assigned_district_region_id,
    assigned_facility.state_slug as assigned_state_slug,
    assigned_facility.state_region_id as assigned_state_region_id,
    assigned_facility.organization_slug as assigned_organization_slug,
    assigned_facility.organization_region_id as assigned_organization_region_id,

    ------------------------------------------------------------
    -- information on registration facility and parent regions
    p.registration_facility_id AS patient_registration_facility_id,
    registration_facility.facility_slug as registration_facility_slug,
    registration_facility.facility_region_id as registration_facility_region_id,
    registration_facility.block_slug as registration_block_slug,
    registration_facility.block_region_id as registration_block_region_id,
    registration_facility.district_slug as registration_district_slug,
    registration_facility.district_region_id as registration_district_region_id,
    registration_facility.state_slug as registration_state_slug,
    registration_facility.state_region_id as registration_state_region_id,
    registration_facility.organization_slug as registration_organization_slug,
    registration_facility.organization_region_id as registration_organization_region_id,

    ------------------------------------------------------------
    -- latest visit info for the month
    bps.blood_pressure_recorded_at AS bp_recorded_at,
    bps.systolic,
    bps.diastolic,
    visits.visited AS visited_at,
    p.recorded_at AT TIME ZONE 'utc' AT TIME ZONE (SELECT current_setting('TIMEZONE')) as recorded_at,


    (cal.year - DATE_PART('year', p.recorded_at AT TIME ZONE 'utc' AT TIME ZONE (SELECT current_setting('TIMEZONE')))) * 12 +
    (cal.month - DATE_PART('month', p.recorded_at AT TIME ZONE 'utc' AT TIME ZONE (SELECT current_setting('TIMEZONE'))))
    AS months_since_registration,

    CASE
        WHEN mh.hypertension = 'yes' AND (bps.systolic >= 180 OR bps.diastolic >= 110) THEN 'Stage 3'
        WHEN mh.hypertension = 'yes' AND (bps.systolic >= 160 OR bps.diastolic >= 100) THEN 'Stage 2'
        WHEN mh.hypertension = 'yes' AND (bps.systolic >= 140 OR bps.diastolic >= 90) THEN 'Stage 1'
        WHEN mh.hypertension = 'yes' AND (bps.systolic < 140 AND bps.diastolic < 90) THEN 'Controlled'
        WHEN mh.hypertension = 'yes' AND (bps.systolic IS null) THEN 'Hypertensive Unknown Stage'
        WHEN mh.hypertension = 'unknown' THEN 'Unknown'
        WHEN mh.hypertension = 'no' THEN 'Not hypertensive'
        ELSE 'Undefined'
        END
        AS diagnosed_disease_state,

    CASE
        WHEN visits.months_since_visit < 3 THEN 'Less than 3 months'
        WHEN visits.months_since_visit < 6 THEN 'Between 3 and 6 months'
        WHEN visits.months_since_visit < 9 THEN 'Between 6 and 9 months'
        WHEN visits.months_since_visit < 12 THEN 'Between 9 and 12 months'
        WHEN visits.months_since_visit >= 12 THEN 'More than 12 months'
        WHEN visits.months_since_visit IS null THEN 'No visit'
        ELSE 'Undefined'
        END
        AS time_since_last_visit,

    CASE
        WHEN bps.months_since_bp_observation < 3 THEN 'Less than 3 months'
        WHEN bps.months_since_bp_observation < 6 THEN 'Between 3 and 6 months'
        WHEN bps.months_since_bp_observation < 9 THEN 'Between 6 and 9 months'
        WHEN bps.months_since_bp_observation < 12 THEN 'Between 9 and 12 months'
        WHEN bps.months_since_bp_observation >= 12 THEN 'More than 12 months'
        WHEN bps.months_since_bp_observation IS null THEN 'No measurement'
        ELSE 'Undefined'
        END
        AS time_since_last_bp,

    ------------------------------------------------------------
    -- lost to follow up
    (
      (cal.year - DATE_PART('year', p.recorded_at AT TIME ZONE 'utc' AT TIME ZONE (SELECT current_setting('TIMEZONE')))) * 12 +
      (cal.month - DATE_PART('month', p.recorded_at AT TIME ZONE 'utc' AT TIME ZONE (SELECT current_setting('TIMEZONE')))) >= 12

      AND (bps.months_since_bp_observation IS NULL OR bps.months_since_bp_observation >= 12)
      AND mh.hypertension = 'yes'
      AND p.status <> 'dead'
      AND p.deleted_at IS NULL
    ) AS lost_to_follow_up

FROM patients p
-- Only fetch BPs that happened on or before the selected calendar month
-- We use year and month comparisons to avoid timezone errors
LEFT OUTER JOIN calendar_months cal
    ON to_char(p.recorded_at AT TIME ZONE 'utc' AT TIME ZONE (SELECT current_setting('TIMEZONE')), 'YYYY-MM') <= to_char(cal.month_date, 'YYYY-MM')
LEFT OUTER JOIN patient_blood_pressures_per_month bps
    ON p.id = bps.patient_id AND cal.month = bps.month AND cal.year = bps.year
LEFT OUTER JOIN patient_visits_per_month visits
    ON p.id = visits.patient_id AND cal.month = visits.month AND cal.year = visits.year
LEFT OUTER JOIN medical_histories mh
    ON p.id = mh.patient_id
INNER JOIN reporting_facilities registration_facility
    ON registration_facility.facility_id = p.registration_facility_id
INNER JOIN reporting_facilities assigned_facility
    ON assigned_facility.facility_id = p.assigned_facility_id
ORDER BY
    p.id,
    cal.month_date ASC
