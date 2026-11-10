-- 02_cleaning.sql
-- Builds clean.requests: typed columns, trimmed text, derived time-to-close, and flags.
-- No row is deleted. Each exclusion rule becomes a flag so the analysis population is explicit
-- and every count is logged in clean.cleaning_log.
--
-- Decisions (agreed with the project owner):
--   * Cancelled requests are excluded from time-to-close and the 7-day closure rate.
--   * Requests with no council district are labelled 'Unassigned' (not dropped).
--   * The 7-day closure threshold is an ASSUMPTION (no official city target was found).
--
-- Run:  \i sql/02_cleaning.sql   (connected to la311, after 01_staging.sql)

CREATE SCHEMA IF NOT EXISTS clean;

DROP TABLE IF EXISTS clean.cleaning_log;
DROP TABLE IF EXISTS clean.requests CASCADE;

CREATE TABLE clean.requests AS
WITH typed AS (
    SELECT
        btrim(srnumber)                                              AS sr_number,
        NULLIF(btrim(createddate), '')::timestamp                    AS created_at,
        NULLIF(btrim(updateddate), '')::timestamp                    AS updated_at,
        NULLIF(btrim(closeddate), '')::timestamp                     AS closed_at,
        NULLIF(btrim(servicedate), '')::timestamp                    AS scheduled_service_at,
        NULLIF(btrim(requesttype), '')                               AS request_type,
        NULLIF(btrim(status), '')                                    AS status,
        NULLIF(btrim(requestsource), '')                             AS request_source,
        NULLIF(btrim(owner), '')                                     AS owner,
        NULLIF(btrim(assignto), '')                                  AS assigned_to,
        CASE WHEN btrim(cd) ~ '^[0-9]+$' THEN btrim(cd)::int END     AS council_district,
        NULLIF(btrim(ncname), '')                                    AS neighborhood_council,
        NULLIF(btrim(zipcode), '')                                   AS zip_code,
        CASE WHEN btrim(latitude)  ~ '^-?[0-9]+(\.[0-9]+)?$' THEN btrim(latitude)::numeric  END AS latitude,
        CASE WHEN btrim(longitude) ~ '^-?[0-9]+(\.[0-9]+)?$' THEN btrim(longitude)::numeric END AS longitude
    FROM staging.requests_raw
)
SELECT
    t.*,
    CASE WHEN t.council_district IS NULL THEN 'Unassigned'
         ELSE 'CD ' || lpad(t.council_district::text, 2, '0') END    AS district_label,
    -- days from creation to close; NULL when there is no usable close date
    CASE WHEN t.closed_at IS NOT NULL AND t.closed_at >= t.created_at
         THEN round((EXTRACT(EPOCH FROM (t.closed_at - t.created_at)) / 86400.0)::numeric, 4)
    END                                                              AS days_to_close,
    (t.status = 'Cancelled')                                         AS is_cancelled,
    (t.status IN ('Open', 'Pending'))                                AS is_still_open,
    -- population for time-to-close KPIs: closed, with a usable close date
    (t.status = 'Closed' AND t.closed_at IS NOT NULL AND t.closed_at >= t.created_at)
                                                                     AS in_close_time_population,
    -- population for the 7-day closure rate: everything except cancelled requests
    (t.status IS DISTINCT FROM 'Cancelled')                          AS in_closure_rate_population
FROM typed t;

ALTER TABLE clean.requests ADD PRIMARY KEY (sr_number);
CREATE INDEX ix_requests_type     ON clean.requests (request_type);
CREATE INDEX ix_requests_district ON clean.requests (council_district);
CREATE INDEX ix_requests_created  ON clean.requests (created_at);

-- Cleaning log: one row per rule, with the number of rows it touches.
CREATE TABLE clean.cleaning_log (
    rule          text PRIMARY KEY,
    rows_affected integer NOT NULL,
    note          text
);

INSERT INTO clean.cleaning_log (rule, rows_affected, note)
SELECT 'rows_loaded', count(*), 'rows in staging.requests_raw' FROM staging.requests_raw
UNION ALL SELECT 'rows_in_clean_table', count(*), 'no rows are deleted' FROM clean.requests
UNION ALL SELECT 'duplicate_sr_numbers', count(*) - count(DISTINCT sr_number), 'primary key would have failed if > 0' FROM clean.requests
UNION ALL SELECT 'unparseable_created_at', count(*) FILTER (WHERE created_at IS NULL), 'should be 0' FROM clean.requests
UNION ALL SELECT 'no_close_date', count(*) FILTER (WHERE closed_at IS NULL), 'close date not populated (open, pending, or request types that do not use it)' FROM clean.requests
UNION ALL SELECT 'closed_before_created', count(*) FILTER (WHERE closed_at < created_at), 'close date earlier than created date; days_to_close set to NULL' FROM clean.requests
UNION ALL SELECT 'closed_status_without_close_date', count(*) FILTER (WHERE status = 'Closed' AND days_to_close IS NULL), 'status Closed but no usable close date; excluded from time-to-close' FROM clean.requests
UNION ALL SELECT 'cancelled_requests', count(*) FILTER (WHERE is_cancelled), 'excluded from time-to-close and closure rate' FROM clean.requests
UNION ALL SELECT 'still_open_or_pending', count(*) FILTER (WHERE is_still_open), 'status Open or Pending in the snapshot; kept in the closure rate as not-closed' FROM clean.requests
UNION ALL SELECT 'no_council_district', count(*) FILTER (WHERE council_district IS NULL), 'labelled Unassigned' FROM clean.requests
UNION ALL SELECT 'in_close_time_population', count(*) FILTER (WHERE in_close_time_population), 'rows used for median / P90 time-to-close' FROM clean.requests
UNION ALL SELECT 'in_closure_rate_population', count(*) FILTER (WHERE in_closure_rate_population), 'rows used for the 7-day closure rate' FROM clean.requests;

SELECT * FROM clean.cleaning_log ORDER BY rule;
