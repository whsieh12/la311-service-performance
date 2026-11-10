-- 01_staging.sql
-- Loads the raw MyLA311 CSV into an all-text staging table, exactly as delivered.
-- Nothing is cleaned or typed here; every value stays text so the load cannot fail on bad data.
--
-- How to run (psql / "SQL Shell (psql)" from the Start menu), connected to la311:
--   \cd 'path/to/la311-service-performance'   (the repo folder)
--   \i sql/01_staging.sql
-- \copy reads the file on YOUR machine, so no server file permissions are needed.

\encoding UTF8

CREATE SCHEMA IF NOT EXISTS staging;

DROP TABLE IF EXISTS staging.requests_raw;

CREATE TABLE staging.requests_raw (
    srnumber                   text,
    createddate                text,
    updateddate                text,
    actiontaken                text,
    owner                      text,
    requesttype                text,
    status                     text,
    requestsource              text,
    createdbyuserorganization  text,
    mobileos                   text,
    anonymous                  text,
    assignto                   text,
    servicedate                text,
    closeddate                 text,
    addressverified            text,
    approximateaddress         text,
    address                    text,
    housenumber                text,
    direction                  text,
    streetname                 text,
    suffix                     text,
    zipcode                    text,
    latitude                   text,
    longitude                  text,
    location                   text,
    tbmpage                    text,
    tbmcolumn                  text,
    tbmrow                     text,
    apc                        text,
    cd                         text,
    cdmember                   text,
    nc                         text,
    ncname                     text,
    policeprecinct             text
);

\copy staging.requests_raw FROM 'data/raw/b7dx-7gc3.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

-- Load check: expect 397043 rows and a created-date range inside Q3 2024.
SELECT count(*)                         AS rows_loaded,
       count(DISTINCT srnumber)         AS distinct_sr_numbers,
       min(createddate)                 AS first_created,
       max(createddate)                 AS last_created
FROM staging.requests_raw;
