"""
Generate the Power BI source data workbook: one sheet per dimension/fact
table in the fact-constellation model, sourced from the same verified
numbers already documented in sql/0X_*.sql header comments and used in
tools/generate_excel_report.py. Plain tabular sheets only (no styling) —
this file is a Power Query import source, not a stakeholder deliverable.

Usage:
    python tools/generate_powerbi_source.py

Output:
    dashboards/powerbi_source_data.xlsx
"""

from pathlib import Path

import pandas as pd

OUTPUT_PATH = Path(__file__).resolve().parent.parent / "dashboards" / "powerbi_source_data.xlsx"

# ============================================================
# Dimensions
# ============================================================

dim_category = pd.DataFrame([
    ["construction", "DIY / Home Improvement", "Y"],
    ["electronics", "Electronics", ""],
    ["appliances", "Appliances", ""],
    ["unknown", "Unknown / No Category", ""],
    ["apparel", "Apparel", ""],
    ["computers", "Computers & Peripherals", ""],
    ["sport", "Sports & Outdoor", ""],
    ["furniture", "Furniture & Home", ""],
    ["country_yard", "Garden & Dacha", ""],
    ["auto", "Auto", ""],
    ["kids", "Kids", ""],
    ["accessories", "Accessories", ""],
    ["stationery", "Stationery", ""],
    ["medicine", "Medicine", ""],
], columns=["CategoryCode", "DisplayName", "TaxonomyMislabeledFlag"])

dim_segment = pd.DataFrame([
    ["Champion", 1],
    ["Loyal", 2],
    ["At Risk", 3],
    ["Others", 4],
    ["Recent but Infrequent", 5],
    ["Lost", 6],
], columns=["Segment", "SortOrder"])

dim_brand = pd.DataFrame({
    "Brand": ["apple", "samsung", "xiaomi", "huawei", "oppo", "lucente", "lg", "sony", "acer", "lenovo"]
})

dim_months_since_first = pd.DataFrame([
    ["M0", 0], ["M1", 1], ["M2", 2], ["M3", 3], ["M4", 4], ["M5", 5], ["M6", 6],
], columns=["MonthsSinceFirst", "SortOrder"])

# ============================================================
# Facts — Module 1: Funnel Analysis
# ============================================================

fact_funnel_by_category = pd.DataFrame([
    ["construction", 23052672, 3462460, 1898778, 0.0824],
    ["electronics", 19472466, 2061398, 1130860, 0.0581],
    ["appliances", 15715297, 1615685, 786186, 0.0500],
    ["sport", 5712881, 593960, 265666, 0.0465],
    ["unknown", 16804172, 1395989, 676904, 0.0403],
    ["auto", 1457937, 93210, 48078, 0.0330],
    ["furniture", 5466667, 403192, 172881, 0.0316],
    ["computers", 5700141, 362813, 173853, 0.0305],
    ["apparel", 12854885, 929354, 388777, 0.0302],
    ["country_yard", 345259, 26255, 9532, 0.0276],
], columns=["CategoryCode", "Views", "Carts", "Purchases", "ConversionPct"])

fact_funnel_by_brand = pd.DataFrame([
    ["samsung", 16383360, 1279265, 0.0781, 0.5742],
    ["apple", 12545341, 997688, 0.0795, 0.5700],
    ["xiaomi", 8975402, 457372, 0.0510, 0.4752],
    ["huawei", 3534417, 190515, 0.0539, 0.5596],
    ["oppo", 1670660, 99562, 0.0596, 0.5810],
    ["lucente", 2017765, 91893, 0.0455, 0.6396],
    ["lg", 1910874, 77650, 0.0406, 0.4886],
    ["sony", 1915499, 65243, 0.0341, 0.4674],
], columns=["Brand", "Views", "Purchases", "OverallConvPct", "CartToPurchasePct"])

# ============================================================
# Facts — Module 2: Session Analytics
# ============================================================

fact_session_depth = pd.DataFrame([
    ["1 event", 36377146, 53442, 0.0015],
    ["2-5 events", 32911072, 2518249, 0.0765],
    ["6-10 events", 11260308, 1596659, 0.1418],
    ["11-20 events", 6259229, 872343, 0.1394],
    ["21-50 events", 2559907, 359341, 0.1404],
    ["51+ events", 325933, 49900, 0.1531],
], columns=["EventBucket", "TotalSessions", "PurchasingSessions", "ConversionPct"])

fact_converting_vs_non = pd.DataFrame([
    ["Converting", 5449934, 8.90, 6, 1.74, 4.38],
    ["Non-Converting", 84243661, 4.31, 2, 0.11, 0.50],
], columns=["SessionType", "Sessions", "AvgEvents", "MedianEvents", "AvgCarts", "MedianDurationMin"])

# ============================================================
# Facts — Module 3: RFM Segmentation
# ============================================================

fact_rfm_segment = pd.DataFrame([
    ["Champion", 0.1323, 0.4140, 27.8, 9.24, 3117.85],
    ["Loyal", 0.2645, 0.2566, 54.7, 3.69, 966.62],
    ["At Risk", 0.2031, 0.2218, 152.6, 3.53, 1087.71],
    ["Others", 0.2064, 0.0572, 130.2, 1.00, 276.00],
    ["Recent but Infrequent", 0.1400, 0.0356, 27.3, 1.00, 253.60],
    ["Lost", 0.0536, 0.0148, 182.4, 1.00, 274.59],
], columns=["Segment", "PctUsers", "PctRevenue", "AvgRecencyDays", "AvgFrequency", "AvgMonetary"])

fact_rfm_monetary_dist = pd.DataFrame([
    ["Champion", 792.74, 1384.98, 2869.93, 6210.49, 790120.94],
    ["At Risk", 211.68, 465.34, 1081.29, 2366.60, 473119.39],
    ["Loyal", 180.07, 361.06, 830.60, 2002.10, 474648.46],
    ["Others", 82.33, 170.15, 311.08, 733.30, 2574.07],
    ["Lost", 77.22, 169.35, 308.86, 719.68, 2574.07],
    ["Recent but Infrequent", 64.33, 166.77, 302.08, 591.78, 2574.07],
], columns=["Segment", "P25", "Median", "P75", "P90", "Max"])

# ============================================================
# Facts — Module 4: Cohort Retention (long format — blank rows omitted, not zeroed)
# ============================================================

_cohort_matrix = [
    ("Oct 2019", [1.00, 0.263, 0.219, 0.137, 0.127, 0.122, 0.081]),
    ("Nov 2019", [1.00, 0.221, 0.122, 0.115, 0.111, 0.077]),
    ("Dec 2019", [1.00, 0.152, 0.125, 0.120, 0.081]),
    ("Jan 2020", [1.00, 0.184, 0.136, 0.088]),
    ("Feb 2020", [1.00, 0.190, 0.104]),
    ("Mar 2020", [1.00, 0.151]),
    ("Apr 2020", [1.00]),
]
_rows = []
for cohort, values in _cohort_matrix:
    for i, v in enumerate(values):
        _rows.append([cohort, f"M{i}", v])
fact_cohort_retention = pd.DataFrame(_rows, columns=["CohortMonth", "MonthsSinceFirst", "RetentionRate"])

fact_retention_curve = pd.DataFrame([
    ["M0", 1.00, 1.00, 1.00],
    ["M1", 0.1936, 0.1513, 0.2630],
    ["M2", 0.1412, 0.1038, 0.2193],
    ["M3", 0.1149, 0.0879, 0.1373],
    ["M4", 0.1063, 0.0812, 0.1270],
    ["M5", 0.0994, 0.0767, 0.1221],
    ["M6", 0.0808, 0.0808, 0.0808],
], columns=["MonthsSinceFirst", "AvgRetention", "MinRetention", "MaxRetention"])

dim_cohort_month = pd.DataFrame([
    ["Oct 2019", 1, 347118], ["Nov 2019", 2, 350352], ["Dec 2019", 3, 347286],
    ["Jan 2020", 4, 215886], ["Feb 2020", 5, 225048], ["Mar 2020", 6, 258674],
    ["Apr 2020", 7, 320535],
], columns=["CohortMonth", "SortOrder", "CohortUsers"])

# ============================================================
# Facts — Module 5: Category & Brand Performance
# ============================================================

fact_category_performance = pd.DataFrame([
    ["construction", 77482657, 2442248, 1008523959, 412.95],
    ["electronics", 69201207, 1341139, 511171792, 381.15],
    ["appliances", 63417883, 925763, 237020688, 256.03],
    ["unknown", 62105978, 768060, 99842875, 129.99],
    ["apparel", 41137209, 455370, 62552043, 137.37],
    ["computers", 18733089, 202396, 49987328, 246.98],
    ["sport", 16145807, 316243, 41518787, 131.29],
    ["furniture", 17652355, 197485, 23122285, 117.08],
], columns=["CategoryCode", "Views", "Purchases", "TotalRevenue", "AvgPrice"])

fact_top_brands = pd.DataFrame([
    ["apple", 1246326, 929321587, 745.65, 11],
    ["samsung", 1567074, 425423961, 271.48, 12],
    ["xiaomi", 542848, 91406924, 168.38, 13],
    ["huawei", 227722, 42203598, 185.33, 10],
    ["lg", 91108, 38260344, 419.94, 9],
    ["acer", 61939, 31996239, 516.58, 8],
    ["sony", 75995, 28528875, 375.40, 12],
    ["lucente", 108910, 28410590, 260.86, 10],
    ["oppo", 119433, 26428298, 221.28, 3],
    ["lenovo", 57028, 22197927, 389.25, 9],
], columns=["Brand", "Purchases", "TotalRevenue", "AvgPrice", "CategoriesCount"])

# ============================================================
# Facts — Module 6: Anomaly Detection
# ============================================================

fact_price_outliers = pd.DataFrame([
    ["construction", 2442248, 158.52, 614.51, 455.99, 1298.49, 2574.07, 118608, 0.04857, 2.0],
    ["unknown", 768060, 34.75, 144.66, 109.91, 309.52, 2574.07, 79648, 0.10370, 8.3],
    ["electronics", 1341139, 134.78, 496.77, 361.99, 1039.76, 2574.07, 78618, 0.05862, 2.5],
    ["apparel", 455370, 32.95, 154.44, 121.49, 336.67, 2557.59, 58771, 0.12906, 7.6],
    ["appliances", 925763, 77.20, 367.81, 290.61, 803.73, 2574.04, 27724, 0.02995, 3.2],
    ["furniture", 197485, 21.62, 111.46, 89.84, 246.22, 2574.07, 20521, 0.10391, 10.5],
    ["computers", 202396, 58.95, 283.12, 224.17, 619.38, 2574.04, 18572, 0.09176, 4.2],
    ["kids", 93757, 29.32, 128.68, 99.36, 277.72, 2574.04, 7525, 0.08026, 9.3],
    ["sport", 316243, 38.10, 169.61, 131.51, 366.88, 2573.81, 5000, 0.01581, 7.0],
    ["accessories", 36854, 20.10, 86.49, 66.39, 186.07, 2254.33, 1309, 0.03552, 12.1],
    ["country_yard", 10849, 7.44, 36.01, 28.57, 78.86, 859.74, 977, 0.09005, 10.9],
    ["auto", 54205, 51.22, 283.92, 232.70, 632.97, 2290.92, 913, 0.01684, 3.6],
    ["stationery", 1872, 8.70, 72.07, 63.37, 167.12, 942.88, 269, 0.14370, 5.6],
    ["medicine", 2583, 12.74, 41.13, 28.39, 83.72, 289.30, 43, 0.01665, 3.5],
], columns=["CategoryCode", "TotalPurchases", "Q1", "Q3", "IQR", "UpperFence", "MaxPrice",
            "OutlierCount", "OutlierPct", "MaxToFenceRatio"])

fact_anomaly_findings = pd.DataFrame([
    ["Price cap confirmed", "All major categories hit an identical max price ($2,574.07) - a platform-level price ceiling, not fraud."],
    ["Bot detection", "374 sessions with >500 events; top 10 all show 0 purchases, views only - confirmed scrapers."],
    ["Logging gap", "Feb 27, 2020: 197,047 events vs ~2M normal (z=-18.84) - the only confirmed data outage."],
    ["Taxonomy shift", "'construction' category revenue jumped from <$1.1M/month to $217M in the week of Dec 2, 2019 - Apple/Samsung/Xiaomi reclassified from electronics."],
], columns=["Finding", "Detail"])

# ============================================================
# Facts — Module 7: COVID Quasi-Experiment
# ============================================================

fact_covid_comparison = pd.DataFrame([
    ["Session Conversion %", 0.0584, 0.0689, "+18.0%"],
    ["Avg Order Value ($)", 307.49, 271.67, "-11.7%"],
    ["Avg Events / Session", 4.39, 5.50, "+25.3%"],
    ["Avg Products Viewed", 2.79, 3.41, "+22.2%"],
    ["Avg Session Revenue ($)", 389.23, 333.68, "-14.3%"],
], columns=["Metric", "PreCovid", "CovidOnset", "ChangeText"])

fact_category_mix_shift = pd.DataFrame([
    ["appliances", 0.1106, 0.1645, 5.4],
    ["electronics", 0.0719, 0.1172, 4.5],
    ["apparel", 0.0344, 0.0469, 1.2],
    ["unknown", 0.0238, 0.0443, 2.0],
    ["sport", 0.0284, 0.0201, -0.8],
    ["computers", 0.0154, 0.0111, -0.4],
], columns=["CategoryCode", "PreCovidSharePct", "CovidSharePct", "DeltaPP"])

# ============================================================
# Write workbook — one sheet per table
# ============================================================

SHEETS = {
    "DimCategory": dim_category,
    "DimSegment": dim_segment,
    "DimBrand": dim_brand,
    "DimMonthsSinceFirst": dim_months_since_first,
    "DimCohortMonth": dim_cohort_month,
    "FactFunnelByCategory": fact_funnel_by_category,
    "FactFunnelByBrand": fact_funnel_by_brand,
    "FactSessionDepth": fact_session_depth,
    "FactConvertingVsNon": fact_converting_vs_non,
    "FactRFMSegment": fact_rfm_segment,
    "FactRFMMonetaryDist": fact_rfm_monetary_dist,
    "FactCohortRetention": fact_cohort_retention,
    "FactRetentionCurve": fact_retention_curve,
    "FactCategoryPerformance": fact_category_performance,
    "FactTopBrands": fact_top_brands,
    "FactPriceOutliers": fact_price_outliers,
    "FactAnomalyFindings": fact_anomaly_findings,
    "FactCovidComparison": fact_covid_comparison,
    "FactCategoryMixShift": fact_category_mix_shift,
}


def main():
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    with pd.ExcelWriter(OUTPUT_PATH, engine="openpyxl") as writer:
        for sheet_name, df in SHEETS.items():
            df.to_excel(writer, sheet_name=sheet_name, index=False)
    print(f"Workbook saved to {OUTPUT_PATH}")
    print(f"{len(SHEETS)} sheets written:")
    for name, df in SHEETS.items():
        print(f"  {name}: {len(df)} rows, {len(df.columns)} cols")


if __name__ == "__main__":
    main()
