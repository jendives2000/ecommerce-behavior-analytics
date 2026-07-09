"""
Populates Description metadata on every measure and column in the live
Power BI Desktop session, via the Power BI Modeling MCP server (driven
directly over stdio - see tools/pbi_mcp_client.py). Written explainability-
first: every description should be understandable by someone with zero
prior context on this project (a recruiter, an interviewer), consistent
with the portfolio's target audience.

Run with Power BI Desktop open on ecommerce_behavior_analytics.pbip and
a live local instance available (checked via connection_operations
ListLocalInstances beforehand).

Usage:
    python tools/pbi_apply_descriptions.py
"""

from pbi_mcp_client import run_sequence, _extract_text

CONNECTION_STRING = "Data Source=localhost:50981;Application Name=MCP-PBIModeling"

# ============================================================
# Measure descriptions, grouped by host table
# ============================================================

MEASURE_DESCRIPTIONS = {
    "_Measures": {
        "Total Events": "Total number of tracked events (views, cart adds, purchases) across the entire dataset, October 2019 through April 2020. Fixed value from the verified BigQuery row count - this model doesn't import raw event-level data, so it can't be recalculated from what's here.",
        "Purchasing Users": "Number of distinct users who made at least one purchase during the tracked period. Fixed value from the RFM analysis - user-level detail isn't imported into this model.",
        "Overall Conversion Rate": "Share of all product views across the entire dataset that led to a purchase, covering all 14 categories. Fixed value - the FactFunnelByCategory table only holds the top 10 categories, so recalculating from it here would undercount.",
        "Total Revenue": "Total purchase revenue across all 14 categories, in US dollars. Fixed value for the same reason as Overall Conversion Rate - the imported category tables only cover a subset.",
        "Cart Abandonment Rate": "Share of shopping-cart sessions that never turned into a purchase. Fixed value, calculated from the full dataset outside this model.",
        "Champion Revenue Share": "Share of total revenue that comes from the 'Champion' customer segment (the top tier in the Recency-Frequency-Monetary scoring model). Recalculates live from FactRFMSegment, since that table covers all 6 segments.",
        "Month-1 Retention Avg": "Average share of customers still active one month after their first purchase, averaged across all acquisition cohorts. Recalculates live from FactRetentionCurve.",
        "COVID Session Conversion Lift": "How much session-level conversion rate changed comparing the period before COVID-19 lockdowns to the period right after they began. A positive number means conversion went up. Recalculates live from FactCovidComparison.",
    },
    "FactFunnelByCategory": {
        "Category Conversion Rate": "View-to-purchase conversion rate across whichever categories are currently selected, calculated as total purchases divided by total views - not an average of each category's individual rate. This gives the correct blended rate when more than one category is selected; averaging the percentages directly would unfairly weight small categories the same as large ones.",
    },
    "FactFunnelByBrand": {
        "Brand Conversion Rate": "View-to-purchase conversion rate across whichever brands are selected, calculated as total purchases divided by total views. Gives a correctly blended rate across multiple brands, unlike averaging each brand's individual conversion percentage.",
    },
    "FactSessionDepth": {
        "Session Conversion Rate": "Conversion rate across whichever session-depth buckets are selected, calculated as total purchasing sessions divided by total sessions. Gives a correctly blended rate, unlike averaging each bucket's individual conversion percentage.",
    },
    "FactRFMSegment": {
        "Weighted Avg Monetary (All Segments)": "Average lifetime spend per customer, blended across all segments and weighted by how many customers are in each one. More accurate than simply averaging the 6 segment averages, which would treat a small segment (e.g. Lost, ~5% of customers) as equally important as a large one (e.g. Loyal, ~26%).",
    },
    "FactCohortRetention": {
        "Weighted Avg Retention": "Average retention rate across all acquisition cohorts and all months after first purchase, excluding the trivial 'month zero' point (where retention is always 100% by definition, since everyone is active in their own signup month). Weighted by each cohort's actual size, so large cohorts count more than small ones.",
    },
    "FactCategoryPerformance": {
        "Weighted Avg Price": "Average purchase price across whichever categories are selected, calculated as total revenue divided by total purchases. Gives a correctly blended price across multiple categories, unlike averaging each category's individual average price.",
    },
    "FactTopBrands": {
        "Brand Weighted Avg Price": "Average purchase price across whichever brands are selected, calculated as total revenue divided by total purchases. Gives a correctly blended price across multiple brands.",
    },
    "FactPriceOutliers": {
        "Weighted Outlier Rate": "Share of purchases flagged as statistical price outliers (IQR method - unusually high compared to the typical range for that category), correctly weighted by purchase volume across whichever categories are selected.",
    },
}

# ============================================================
# Column descriptions, grouped by table
# ============================================================

COLUMN_DESCRIPTIONS = {
    "DimBrand": {
        "Brand": "Brand name as recorded in the source data (lowercase, e.g. 'apple', 'samsung'). One row per distinct brand appearing in the funnel or top-brands analysis.",
    },
    "DimCategory": {
        "CategoryCode": "Raw category code as it appears in the original tracking data (e.g. 'construction', 'electronics'). The technical key used to join to the fact tables - see DisplayName for the human-readable version.",
        "DisplayName": "Human-readable category name for use in report visuals (e.g. 'DIY / Home Improvement' instead of the raw code 'construction').",
        "TaxonomyMislabeledFlag": "Set to 'Y' only for the 'construction' category. Flags a known data quality issue: starting the week of December 2, 2019, Apple/Samsung/Xiaomi products were reclassified from 'electronics' into 'construction' on the source platform, so revenue and conversion figures for this category after that date don't reflect genuine DIY/home-improvement demand. See the project README's Data Quality Findings for the full explanation.",
    },
    "DimCohortMonth": {
        "CohortMonth": "The calendar month in which a group of customers made their first purchase (their 'acquisition cohort'). Used to track how each monthly group of new customers behaves over time.",
        "SortOrder": "Chronological sort order for CohortMonth (1 = October 2019 through 7 = April 2020), since the month labels alone don't sort correctly.",
        "CohortUsers": "Number of customers who first purchased in this cohort month. Used to weight retention calculations so larger cohorts count more than smaller ones.",
    },
    "DimMonthsSinceFirst": {
        "MonthsSinceFirst": "How many months after a customer's first purchase this row represents, labeled M0 (the signup month itself) through M6. M0 is always 100% retention by definition.",
        "SortOrder": "Numeric sort order matching MonthsSinceFirst (0 through 6), since 'M0'-'M6' as text wouldn't sort correctly on its own.",
    },
    "DimSegment": {
        "Segment": "Customer segment name from the RFM (Recency, Frequency, Monetary) scoring model: Champion, Loyal, At Risk, Others, Recent but Infrequent, or Lost.",
        "SortOrder": "Fixed display order for the 6 segments, from best (Champion = 1) to weakest (Lost = 6), for consistent chart ordering.",
    },
    "FactFunnelByCategory": {
        "CategoryCode": "Links to DimCategory. One row per one of the top 10 categories by conversion rate - not all 14 (see the README's Module 1 section for the full category list).",
        "Views": "Total product-view events for this category.",
        "Carts": "Total add-to-cart events for this category.",
        "Purchases": "Total purchase events for this category.",
        "ConversionPct": "This specific category's view-to-purchase conversion rate. Read per-row only - don't sum or average this column across categories; use the 'Category Conversion Rate' measure instead for a correctly blended figure.",
    },
    "FactFunnelByBrand": {
        "Brand": "Links to DimBrand. One row per one of the top 8 brands by purchase volume.",
        "Views": "Total product-view events for this brand.",
        "Purchases": "Total purchase events for this brand.",
        "OverallConvPct": "This specific brand's view-to-purchase conversion rate. Read per-row only - use the 'Brand Conversion Rate' measure for a correctly blended figure across multiple brands.",
        "CartToPurchasePct": "Share of this brand's cart-adds that converted to a purchase. Can't be recalculated as a weighted measure like the other rate columns, since this table doesn't store each brand's raw cart count - only Views and Purchases. Read per-row only.",
    },
    "FactSessionDepth": {
        "EventBucket": "A range of how many events happened in a single browsing session (e.g. '1 event', '6-10 events'). Used to see how session depth relates to whether a purchase happens.",
        "TotalSessions": "Number of sessions falling into this event-count bucket.",
        "PurchasingSessions": "Of the sessions in this bucket, how many included a purchase.",
        "ConversionPct": "This bucket's conversion rate. Read per-row only - use the 'Session Conversion Rate' measure for a correctly blended figure.",
    },
    "FactConvertingVsNon": {
        "SessionType": "Either 'Converting' (session included a purchase) or 'Non-Converting'.",
        "Sessions": "Number of sessions of this type.",
        "AvgEvents": "Average number of events per session, for this session type only. Don't sum or average across the two session types.",
        "MedianEvents": "Median number of events per session, for this session type only.",
        "AvgCarts": "Average number of cart-add events per session, for this session type only.",
        "MedianDurationMin": "Median session length in minutes, for this session type only.",
    },
    "FactRFMSegment": {
        "Segment": "Links to DimSegment.",
        "PctUsers": "Share of all purchasing customers that fall into this segment. These percentages add up to 100% across all 6 segments, so summing this column across multiple selected segments is meaningful - unlike most other percentage columns in this model.",
        "PctRevenue": "Share of total revenue generated by this segment. Also adds up to 100% across all 6 segments.",
        "AvgRecencyDays": "Average number of days since a customer's last purchase, for customers in this segment only. Don't sum or average across segments.",
        "AvgFrequency": "Average number of purchases per customer, for this segment only.",
        "AvgMonetary": "Average total lifetime spend per customer, for this segment only. Use the 'Weighted Avg Monetary (All Segments)' measure for a correctly blended figure across multiple segments.",
    },
    "FactRFMMonetaryDist": {
        "Segment": "Links to DimSegment.",
        "P25": "25th percentile (bottom quarter) of lifetime spend for customers in this segment.",
        "Median": "Median (50th percentile) lifetime spend for customers in this segment.",
        "P75": "75th percentile (top quarter) of lifetime spend for customers in this segment.",
        "P90": "90th percentile of lifetime spend for customers in this segment - the top 10% spend at least this much.",
        "Max": "Highest lifetime spend recorded for any single customer in this segment. Several segments cap out at exactly $2,574.07 - the platform's price ceiling per transaction, not a coincidence. See the project's price cap research notes for the full explanation.",
    },
    "FactCohortRetention": {
        "CohortMonth": "Links to DimCohortMonth - the month this cohort of customers first purchased.",
        "MonthsSinceFirst": "Links to DimMonthsSinceFirst - how many months after first purchase this retention figure applies to.",
        "RetentionRate": "Share of this cohort still active (made a purchase) this many months after their first purchase. Combinations the dataset can't yet observe (e.g. a cohort's retention 6 months out, if the dataset doesn't extend that far) are intentionally left out of this table rather than shown as 0% - a blank means 'not yet observable,' not 'nobody came back.'",
    },
    "FactRetentionCurve": {
        "MonthsSinceFirst": "Links to DimMonthsSinceFirst.",
        "AvgRetention": "Average retention rate at this point in the customer lifecycle, averaged across all cohorts that have reached this point.",
        "MinRetention": "Lowest retention rate recorded by any single cohort at this point in the lifecycle.",
        "MaxRetention": "Highest retention rate recorded by any single cohort at this point in the lifecycle.",
    },
    "FactCategoryPerformance": {
        "CategoryCode": "Links to DimCategory. One row per one of the top 8 categories by revenue.",
        "Views": "Total product-view events for this category.",
        "Purchases": "Total purchase events for this category.",
        "TotalRevenue": "Total revenue from this category, in US dollars.",
        "AvgPrice": "Average purchase price for this category. Read per-row only - use the 'Weighted Avg Price' measure for a correctly blended figure across multiple categories.",
    },
    "FactTopBrands": {
        "Brand": "Links to DimBrand. Covers all 10 brands tracked in the top-brands analysis.",
        "Purchases": "Total purchase events for this brand.",
        "TotalRevenue": "Total revenue from this brand, in US dollars.",
        "AvgPrice": "Average purchase price for this brand. Read per-row only - use the 'Brand Weighted Avg Price' measure for a correctly blended figure across multiple brands.",
        "CategoriesCount": "Number of distinct product categories this brand sells in.",
    },
    "FactPriceOutliers": {
        "CategoryCode": "Links to DimCategory. Covers all 14 categories.",
        "TotalPurchases": "Total number of purchases in this category, used as the base for the outlier percentage.",
        "Q1": "25th percentile purchase price for this category - the boundary of the cheapest quarter of purchases.",
        "Q3": "75th percentile purchase price for this category - the boundary of the most expensive quarter of purchases.",
        "IQR": "Interquartile range (Q3 minus Q1) - the width of the 'typical' price band for this category, used to calculate the outlier threshold.",
        "UpperFence": "The outlier detection threshold for this category (Q3 + 1.5 x IQR, the standard statistical rule of thumb). Any purchase above this price is flagged as a statistical outlier.",
        "MaxPrice": "Highest purchase price recorded in this category. In almost every category this is exactly $2,574.07 - a platform-wide price ceiling, not genuine price variation. See the README's Data Quality Findings for the full explanation.",
        "OutlierCount": "Number of purchases in this category priced above the UpperFence threshold.",
        "OutlierPct": "Share of this category's purchases flagged as outliers. Read per-row only - use the 'Weighted Outlier Rate' measure for a correctly blended figure across multiple categories.",
        "MaxToFenceRatio": "How many multiples of the UpperFence threshold the category's MaxPrice reaches (e.g. a ratio of 2.0 means the most expensive purchase was twice the outlier threshold).",
    },
    "FactAnomalyFindings": {
        "Finding": "Short name of a specific data-quality or anomaly finding from the Module 6 analysis (e.g. 'Price cap confirmed', 'Bot detection').",
        "Detail": "Full plain-language explanation of that finding, written for someone with no prior context on the project.",
    },
    "FactCovidComparison": {
        "Metric": "Name of the specific metric being compared (e.g. 'Session Conversion %', 'Avg Order Value ($)'). Each row is a different metric in a different unit.",
        "PreCovid": "This metric's value during the pre-COVID baseline period. Never sum this column across rows - each row is a different metric in a different unit (percentage, dollars, event count), so a sum would be meaningless.",
        "CovidOnset": "This metric's value during the COVID-onset period, for comparison against PreCovid.",
        "ChangeText": "The relative change from PreCovid to CovidOnset for this metric. Same caveat as the other columns - never sum across rows.",
    },
    "FactCategoryMixShift": {
        "CategoryCode": "Links to DimCategory. Covers only the 6 categories whose revenue share moved the most around COVID onset - not all 14.",
        "PreCovidSharePct": "This category's share of total revenue before COVID onset. Because this table only lists 6 of 14 categories, don't sum this column expecting it to reach 100%.",
        "CovidSharePct": "This category's share of total revenue after COVID onset, for comparison against PreCovidSharePct.",
        "DeltaPP": "Change in revenue share for this category, in percentage points (COVID-onset share minus pre-COVID share). Positive means this category grew its share of the pie during COVID.",
    },
}


def build_measure_calls():
    calls = []
    for table_name, measures in MEASURE_DESCRIPTIONS.items():
        definitions = [
            {"Name": name, "TableName": table_name, "Description": desc}
            for name, desc in measures.items()
        ]
        calls.append(("measure_operations", {"Operation": "Update", "Definitions": definitions}))
    return calls


def build_column_calls():
    calls = []
    for table_name, columns in COLUMN_DESCRIPTIONS.items():
        definitions = [
            {"Name": name, "TableName": table_name, "Description": desc}
            for name, desc in columns.items()
        ]
        calls.append(("column_operations", {"Operation": "Update", "Definitions": definitions}))
    return calls


if __name__ == "__main__":
    calls = [("connection_operations", {"operation": "Connect", "ConnectionString": CONNECTION_STRING})]
    calls += build_measure_calls()
    calls += build_column_calls()

    results = run_sequence(calls)

    print("Connect:", _extract_text(results[0]))
    print()
    idx = 1
    for table_name in MEASURE_DESCRIPTIONS:
        print(f"Measures [{table_name}]: {_extract_text(results[idx])}")
        idx += 1
    print()
    for table_name in COLUMN_DESCRIPTIONS:
        print(f"Columns [{table_name}]: {_extract_text(results[idx])}")
        idx += 1
