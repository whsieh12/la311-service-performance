# Expected KPI values (from the pandas profile, corrected Oct 15)

After `sql/03_kpis.sql`, `SELECT * FROM analytics.v_kpi_by_type` should show about these 7-day closure rates (non-cancelled requests):

| Request type | Expected 7-day closure rate |
|---|---|
| Overall | 85.4% |
| Bulky Items | 92.9% |
| Graffiti | 92.3% |
| Metal/Household Appliances | 93.7% |
| Illegal Dumping | 86.2% |
| Electronic Waste | 94.3% |
| Dead Animal | 99.9% |
| Homeless Encampment | 24.7% (51.2% ever closed) |
| Multiple Streetlight | 3.7% |
| Single Streetlight | 2.4% |

`still_open` total should be 18,793, of which Homeless Encampment is 12,243 (65.1%).
Differences of more than ~0.2 points mean the SQL and pandas disagree: investigate before using the number.
