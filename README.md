# LA311 service request analysis (Q3 2024)

**Question:** which kinds of 311 requests does the City of Los Angeles take longest to complete, and where should operations focus first?

**Status:** SQL cleaning, KPI layer and district analysis are done. The Tableau dashboard is in progress.

- **Data:** MyLA311 service requests created 2024-07-01 to 2024-09-30 (397,043 rows), City of Los Angeles open data, snapshot downloaded 2026-10-13. Source, download date and checksum are in [data/README.md](data/README.md). Raw data is not redistributed.
- **Stack:** PostgreSQL (cleaning, KPI views), Python with pandas and SciPy (district analysis), Tableau Public (dashboard).

## Key findings

**1. Most requests close fast, but two categories do not.** 85.4% of requests close within 7 days. Bulky-item pickup, graffiti removal, dead-animal removal and most other categories close 86 to 100% of the time within a week. Only 24.7% of homeless-encampment requests and 2 to 4% of streetlight repairs do.

| Request type | Requests | Closed within 7 days | Ever closed | Still open |
|---|---:|---:|---:|---:|
| Bulky Items | 184,033 | 92.9% | 99.1% | 1,570 |
| Graffiti Removal | 74,636 | 92.3% | 98.3% | 875 |
| Metal/Household Appliances | 32,904 | 93.7% | 99.8% | 49 |
| Illegal Dumping Pickup | 31,986 | 86.2% | 95.0% | 1,578 |
| Homeless Encampment | 25,075 | 24.7% | 51.2% | 12,243 |
| Electronic Waste | 10,026 | 94.3% | 99.9% | 12 |
| Dead Animal Removal | 9,209 | 99.9% | 99.9% | 1 |
| Multiple Streetlight Issue | 5,984 | 3.7% | 80.6% | 1,155 |
| Single Streetlight Issue | 4,950 | 2.4% | 76.0% | 1,186 |
| Other, Report Water Waste, Feedback | 1,719 | see [exports](exports/) | | 124 |

**2. The unresolved backlog is mostly encampments.** 18,793 requests were still marked Open or Pending in the snapshot, over a year after they were created. 65.1% of them (12,243) are homeless-encampment requests, and another 12.5% are streetlight issues.

**3. Median time to close hides the problem.** Citywide, the median closed request took 1.88 days and the 90th percentile 7.01 days. But those figures only count requests that eventually closed. Only about half of encampment requests and 76 to 81% of streetlight requests ever closed, so their closed-only medians make them look faster than they are. The 7-day closure rate over all requests is a more honest headline KPI.

**4. Request mix explains about half of the gap between council districts, not all of it.**
- The raw 7-day closure rate ranges from 76.2% (CD 01) to 90.4% (CD 07), a spread of 14.2 percentage points.
- Given the mix of request types each district receives, the expected rates range from 80.9% to 88.9% (8.0 points). Districts that receive more streetlight and encampment requests look slower partly because of what residents report.
- After adjusting for mix, observed closures divided by expected closures range from 0.94 to 1.04. Only CD 01 (0.94) is clearly below what its mix predicts.
- Within a single request type, districts still differ for some types. For encampments the best district closes 42.6% within a week and the worst 7.8%; multiple-streetlight issues vary by 22 points, graffiti by 15, illegal dumping by 13. Bulky items vary by under 5 points.
- The data shows where closure rates differ, not why. No cause is claimed.

**Suggested focus (analyst's recommendation, not a measured result):** give streetlight and encampment requests their own tracked queue, and report the 7-day closure rate by request type instead of a single citywide median.

## KPI dictionary

| KPI | Definition |
|---|---|
| 7-day closure rate | Requests closed within 7 days of creation, divided by all non-cancelled requests. The 7-day threshold is an assumption: no official city target was found. |
| Ever-closed rate | Requests with a usable close date, divided by all non-cancelled requests. |
| Median / P90 days to close | Days from creation to close, closed requests only. Biased low for types that often never close. |
| Still open | Status Open or Pending in the snapshot. Because the snapshot was taken over a year after the requests, these are stale or unresolved; the data cannot say which. |
| Mix-adjusted district score | A district's observed 7-day closures divided by the closures expected if each request type closed at its citywide rate. 1.00 means exactly as expected. |

## Method

1. **Load:** the raw CSV is loaded into an all-text staging table, unmodified (`sql/01_staging.sql`).
2. **Clean:** `sql/02_cleaning.sql` builds a typed table. No rows are deleted. Each exclusion rule is a flag and every count is written to `clean.cleaning_log`. All 12 log counts matched independent counts computed with pandas ([docs/validation_expectations.md](docs/validation_expectations.md)).
3. **KPIs:** `sql/03_kpis.sql` creates SQL views for overall, by-type, by-district and type-by-district KPIs and the backlog. Results were checked against [docs/kpi_expectations.md](docs/kpi_expectations.md).
4. **District analysis:** `python/01_export_and_district_analysis.py` exports the views to `exports/` and compares districts raw, within each request type (Cramér's V as the effect size, since with this many requests every p-value is tiny), and after adjusting for request mix.

Cancelled requests (16,521) are excluded from closure KPIs; 768 requests with no council district are labelled "Unassigned" and left out of the district comparison.

## Limitations

- One quarter of data (Q3 2024). No year-over-year or seasonal comparison.
- The 7-day threshold is my assumption, not a city standard.
- Closure status comes from the city's own status field; I did not verify whether a "closed" request was actually fixed.
- Differences between districts are descriptive. They could reflect staffing, how requests are routed or recorded, or the kind of problem reported; this analysis cannot separate them.
- "Still open" means still open in a snapshot taken over a year later, not an end-of-quarter backlog.

## Repository

- `sql/` numbered scripts, run in order: create database, stage, clean, KPI views
- `python/` district analysis and CSV export
- `exports/` CSVs produced for the dashboard
- `docs/` validation expectations and KPI expectations
- `dashboard/` Tableau workbook and screenshots (in progress)

To reproduce: install PostgreSQL, download the dataset (see [data/README.md](data/README.md)), run the SQL scripts in order with `psql`, then run the Python script.

License: MIT (code only; the data is not redistributed).
