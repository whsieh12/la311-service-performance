# Independent expectations (pandas) for SQL reconciliation

These counts were computed with pandas directly from `data/raw/b7dx-7gc3.csv`, independently of the SQL.
After running `sql/02_cleaning.sql`, `SELECT * FROM clean.cleaning_log` should match.

| clean.cleaning_log rule | Expected |
|---|---|
| rows_loaded / rows_in_clean_table | 397,043 |
| duplicate_sr_numbers | 0 |
| unparseable_created_at | 0 |
| no_close_date | 18,886 |
| closed_before_created | 0 |
| closed_status_without_close_date | 57 |
| cancelled_requests | 16,521 |
| still_open_or_pending | 18,793 |
| no_council_district | 768 |
| in_close_time_population | 361,195 |
| in_closure_rate_population | 380,522 |

If any number differs, the SQL or the load is wrong: investigate before moving on.
