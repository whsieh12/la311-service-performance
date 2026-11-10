-- 03_kpis.sql
-- KPI views on top of clean.requests. Definitions (also go in the README KPI dictionary):
--   closed_within_7d     = in_close_time_population AND days_to_close <= 7   (7 days is an ASSUMPTION)
--   closure_rate_7d      = closed_within_7d / requests in closure-rate population (non-cancelled)
--   ever_closed_rate     = in_close_time_population / non-cancelled requests
--   median / P90 days    = closed requests only, so slow types look faster than they are
--   still_open           = status Open or Pending in the snapshot
-- Run:  \i sql/03_kpis.sql   (connected to la311, after 02_cleaning.sql)

CREATE SCHEMA IF NOT EXISTS analytics;

DROP VIEW IF EXISTS analytics.v_kpi_overall, analytics.v_kpi_by_type,
                    analytics.v_kpi_by_district, analytics.v_kpi_type_district,
                    analytics.v_backlog_by_type CASCADE;

CREATE VIEW analytics.v_kpi_overall AS
SELECT
    count(*) FILTER (WHERE in_closure_rate_population)                              AS requests,
    round(100.0 * count(*) FILTER (WHERE in_close_time_population AND days_to_close <= 7)
          / count(*) FILTER (WHERE in_closure_rate_population), 1)                  AS closure_rate_7d_pct,
    round(100.0 * count(*) FILTER (WHERE in_close_time_population)
          / count(*) FILTER (WHERE in_closure_rate_population), 1)                  AS ever_closed_pct,
    round((percentile_cont(0.5) WITHIN GROUP (ORDER BY days_to_close)
           FILTER (WHERE in_close_time_population))::numeric, 2)                    AS median_days_closed_only,
    round((percentile_cont(0.9) WITHIN GROUP (ORDER BY days_to_close)
           FILTER (WHERE in_close_time_population))::numeric, 2)                    AS p90_days_closed_only,
    count(*) FILTER (WHERE is_still_open)                                           AS still_open
FROM clean.requests;

CREATE VIEW analytics.v_kpi_by_type AS
SELECT
    request_type,
    count(*) FILTER (WHERE in_closure_rate_population)                              AS requests,
    round(100.0 * count(*) FILTER (WHERE in_close_time_population AND days_to_close <= 7)
          / NULLIF(count(*) FILTER (WHERE in_closure_rate_population), 0), 1)       AS closure_rate_7d_pct,
    round(100.0 * count(*) FILTER (WHERE in_close_time_population)
          / NULLIF(count(*) FILTER (WHERE in_closure_rate_population), 0), 1)       AS ever_closed_pct,
    round((percentile_cont(0.5) WITHIN GROUP (ORDER BY days_to_close)
           FILTER (WHERE in_close_time_population))::numeric, 2)                    AS median_days_closed_only,
    round((percentile_cont(0.9) WITHIN GROUP (ORDER BY days_to_close)
           FILTER (WHERE in_close_time_population))::numeric, 2)                    AS p90_days_closed_only,
    count(*) FILTER (WHERE is_still_open)                                           AS still_open
FROM clean.requests
GROUP BY request_type;

CREATE VIEW analytics.v_kpi_by_district AS
SELECT
    district_label,
    count(*) FILTER (WHERE in_closure_rate_population)                              AS requests,
    round(100.0 * count(*) FILTER (WHERE in_close_time_population AND days_to_close <= 7)
          / NULLIF(count(*) FILTER (WHERE in_closure_rate_population), 0), 1)       AS closure_rate_7d_pct,
    round((percentile_cont(0.5) WITHIN GROUP (ORDER BY days_to_close)
           FILTER (WHERE in_close_time_population))::numeric, 2)                    AS median_days_closed_only,
    count(*) FILTER (WHERE is_still_open)                                           AS still_open
FROM clean.requests
GROUP BY district_label;

-- Same KPI for every type x district cell, so districts can be compared WITHIN one request type.
CREATE VIEW analytics.v_kpi_type_district AS
SELECT
    request_type,
    district_label,
    count(*) FILTER (WHERE in_closure_rate_population)                              AS requests,
    round(100.0 * count(*) FILTER (WHERE in_close_time_population AND days_to_close <= 7)
          / NULLIF(count(*) FILTER (WHERE in_closure_rate_population), 0), 1)       AS closure_rate_7d_pct,
    round((percentile_cont(0.5) WITHIN GROUP (ORDER BY days_to_close)
           FILTER (WHERE in_close_time_population))::numeric, 2)                    AS median_days_closed_only
FROM clean.requests
GROUP BY request_type, district_label;

-- Open/pending in the snapshot: how much of it each request type makes up.
CREATE VIEW analytics.v_backlog_by_type AS
SELECT
    request_type,
    count(*)                                                                        AS still_open,
    round(100.0 * count(*) / sum(count(*)) OVER (), 1)                              AS share_of_open_pct,
    min(updated_at)::date                                                           AS earliest_last_update,
    max(updated_at)::date                                                           AS latest_last_update
FROM clean.requests
WHERE is_still_open
GROUP BY request_type;

-- Quick look: should match docs/kpi_expectations.md
SELECT * FROM analytics.v_kpi_overall;
SELECT * FROM analytics.v_kpi_by_type ORDER BY requests DESC;
SELECT * FROM analytics.v_backlog_by_type ORDER BY still_open DESC;
