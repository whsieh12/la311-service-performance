"""
01_export_and_district_analysis.py

1) Exports the SQL KPI views to exports/*.csv (inputs for the Tableau dashboard).
2) Tests the district question: do council districts really differ in how fast they close requests,
   or does the gap come from the mix of request types each district receives?

Run from the repo root:   python python/01_export_and_district_analysis.py
Needs: pandas, numpy, scipy, psycopg2-binary. Asks for the Postgres password (or reads PGPASSWORD).
"""
import getpass
import os
from pathlib import Path

import numpy as np
import pandas as pd
import psycopg2
from scipy import stats

EXPORTS = Path("exports")
EXPORTS.mkdir(exist_ok=True)
MIN_TYPE_N = 1000      # request types with fewer requests are skipped in the within-type comparison
MIN_CELL_N = 30        # type x district cells with fewer requests are skipped (rates too noisy)


def query(conn, sql):
    with conn.cursor() as cur:
        cur.execute(sql)
        cols = [c[0] for c in cur.description]
        return pd.DataFrame(cur.fetchall(), columns=cols)


def main():
    password = os.environ.get("PGPASSWORD") or getpass.getpass("Postgres password: ")
    conn = psycopg2.connect(host="localhost", dbname="la311", user="postgres", password=password)

    # ---- 1) export the KPI views -------------------------------------------------------------
    for view in ["v_kpi_overall", "v_kpi_by_type", "v_kpi_by_district",
                 "v_kpi_type_district", "v_backlog_by_type"]:
        df = query(conn, f"SELECT * FROM analytics.{view}")
        df.to_csv(EXPORTS / f"{view}.csv", index=False)
        print(f"exported exports/{view}.csv ({len(df)} rows)")

    # ---- 2) district analysis ----------------------------------------------------------------
    req = query(conn, """
        SELECT request_type, district_label, days_to_close,
               (in_close_time_population AND days_to_close <= 7) AS closed_7d,
               in_close_time_population AS closed
        FROM clean.requests
        WHERE in_closure_rate_population AND council_district IS NOT NULL
    """)
    req["closed_7d"] = req["closed_7d"].astype(bool)
    req["days_to_close"] = req["days_to_close"].astype(float)
    print(f"\nrequests in district analysis: {len(req):,} (Unassigned district excluded)")

    # (a) raw gap: median days to close (closed requests only) by district
    med = req[req["closed"]].groupby("district_label")["days_to_close"].median()
    raw_gap = med.max() / med.min()
    print(f"\n(a) RAW median days-to-close by district: {med.min():.2f} ({med.idxmin()}) "
          f"to {med.max():.2f} ({med.idxmax()})  ->  {raw_gap:.1f}x gap")

    # (b) within each request type: how far apart are districts?
    rows = []
    for rtype, g in req.groupby("request_type"):
        if len(g) < MIN_TYPE_N:
            continue
        cell = g.groupby("district_label").agg(n=("closed_7d", "size"), rate=("closed_7d", "mean"),
                                               median_days=("days_to_close", "median"))
        cell = cell[cell["n"] >= MIN_CELL_N]
        ct = pd.crosstab(g["district_label"], g["closed_7d"])
        chi2, p, _, _ = stats.chi2_contingency(ct)
        cramers_v = np.sqrt(chi2 / (ct.to_numpy().sum() * (min(ct.shape) - 1)))
        rows.append({
            "request_type": rtype,
            "requests": len(g),
            "districts": len(cell),
            "best_district": cell["rate"].idxmax(),
            "best_rate_pct": round(100 * cell["rate"].max(), 1),
            "worst_district": cell["rate"].idxmin(),
            "worst_rate_pct": round(100 * cell["rate"].min(), 1),
            "spread_pts": round(100 * (cell["rate"].max() - cell["rate"].min()), 1),
            "median_days_ratio": round(cell["median_days"].max() / max(cell["median_days"].min(), 0.01), 2),
            "chi2_p": p,
            "cramers_v": round(float(cramers_v), 3),   # effect size: 0 = no district effect, 1 = total
        })
    within = pd.DataFrame(rows).sort_values("requests", ascending=False)
    within.to_csv(EXPORTS / "district_gap_within_type.csv", index=False)
    print("\n(b) WITHIN each request type (7-day closure rate, districts with >= "
          f"{MIN_CELL_N} requests):")
    print(within.drop(columns=["chi2_p"]).to_string(index=False))
    print("Note: with this many requests every p-value is tiny, so read Cramer's V and spread_pts, not p.")

    # (c) mix-adjusted district score: observed 7-day closures / expected given each district's type mix
    city_rate = req.groupby("request_type")["closed_7d"].mean()
    req["expected"] = req["request_type"].map(city_rate)
    d = req.groupby("district_label").agg(requests=("closed_7d", "size"),
                                          observed=("closed_7d", "sum"),
                                          expected=("expected", "sum"))
    d["raw_rate_pct"] = round(100 * d["observed"] / d["requests"], 1)
    d["expected_rate_pct"] = round(100 * d["expected"] / d["requests"], 1)
    d["obs_over_exp"] = round(d["observed"] / d["expected"], 3)
    d = d.drop(columns=["observed", "expected"]).sort_values("obs_over_exp")
    d.to_csv(EXPORTS / "district_mix_adjusted.csv")
    city_overall = req["closed_7d"].mean()
    raw_spread = (d["raw_rate_pct"].max() - d["raw_rate_pct"].min())
    print("\n(c) MIX-ADJUSTED score per district (1.00 = closes exactly as often as its request mix predicts):")
    print(d.to_string())
    print(f"\nraw 7-day closure rate ranges {d['raw_rate_pct'].min()}% to {d['raw_rate_pct'].max()}% "
          f"(spread {raw_spread:.1f} pts); after adjusting for request mix, obs/exp ranges "
          f"{d['obs_over_exp'].min():.3f} to {d['obs_over_exp'].max():.3f}. Citywide rate {100*city_overall:.1f}%.")
    conn.close()


if __name__ == "__main__":
    main()
