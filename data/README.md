# Data provenance

The raw file is NOT committed to Git. To reproduce, download it yourself.

| Item | Value |
|---|---|
| Source | City of LA Open Data, "MyLA311 Service Request Data 2024" (dataset id `b7dx-7gc3`), publisher: City of Los Angeles Information Technology Agency |
| Source page | https://data.lacity.org (search "MyLA311 Service Request Data 2024") |
| Slice used | requests created 2024-07-01 through 2024-09-30 (Q3 2024) |
| Download query | `https://data.lacity.org/resource/b7dx-7gc3.csv?$where=createddate >= '2024-07-01T00:00:00' AND createddate < '2024-10-01T00:00:00'&$limit=500000` |
| Downloaded | 2026-10-13 (file timestamp) |
| File name | `b7dx-7gc3.csv` (place in `data/raw/`) |
| Size | 170,805,301 bytes |
| Rows / columns | 397,043 / 34 |
| SHA-256 | `0a37d6fdefcad8a8405dd5d69752ab39301385249c5aee1683a4bbeb51c50c28` |
| License | The dataset page shows no license. Data is cited to its source and not redistributed. |

Notes
- The portal refreshes daily, so a later download may differ slightly. Compare the hash above.
- Do not open or re-save the CSV in Excel (row limit and date reformatting).
- Column names in the CSV are lowercase.
