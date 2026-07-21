# Data Quality Findings: Full Detail

This file holds the complete evidence trail behind the four data quality findings summarized in the main [README](README.md#data-quality-findings). Each finding follows the same structure: what was found, what it means, how it's handled in this project, and a note on how it would be handled in a production environment with a real data engineering team behind it.

---

## 1. Category Taxonomy Anomaly: `construction` ≠ DIY

**What was found:**
The raw category code `construction` ranked as the #1 revenue category, at 49% of platform revenue (about $1B out of $2.06B). Its top three brands are Apple, Samsung, and Xiaomi, with Apple averaging $868 per purchase inside "DIY / Home Improvement." In October and November 2019, `construction` revenue sat under $1.1M a month. In the week of December 2, 2019, it jumped to $35.3M, and `electronics` collapsed from $36M to $3.7M in that same week. The switch was close to instantaneous.

**What this means:**
This isn't a genuine DIY surge. Smartphones and consumer electronics that had previously been tagged `electronics` started appearing under `construction` beginning in December 2019, a platform-side taxonomy change. From that point on, the `construction` bucket effectively functions as a misclassified electronics catch-all, and the display name "DIY / Home Improvement" is misleading for the period.

**How it's handled:**
SQL queries and visualizations flag this explicitly. Category-level metrics treat `construction` as directional at best after December 2019. The underlying data stays untouched; the anomaly is disclosed rather than corrected. Category analysis in Module 5 and Module 7 should be read with this in mind.

**Real-world note:**
Building a "corrected" copy of this data, recoding the affected rows back to `electronics`, would be technically easy (flip any `construction` row from Apple, Samsung, or Xiaomi dated on or after Dec 2, 2019). That was deliberately left undone. The aggregate evidence that something is wrong here is airtight, but a row-level correction would need row-level ground truth this project doesn't have. The brand-and-date heuristic above is still an inference rather than a confirmed mapping, and presenting a heuristic recode as clean data would blur the line between "verified" and "well-evidenced guess" for anyone downstream. In a production environment, this is the kind of finding an analyst escalates rather than quietly patches. REES46 is a third-party CDP sitting between the retailer and this dataset, so a real fix needs confirmation from whichever side owns the category mapping: REES46's data integration team, if their ingestion pipeline mis-tagged the feed, or the retailer's own product and catalog system, if the reclassification happened upstream before REES46 ever saw it. An analyst's job here is to surface, quantify, and disclose. Correcting the source-of-truth taxonomy belongs to whoever owns it.

---

## 2. Logging Gap: February 27, 2020

**What was found:**
On February 27, 2020, the platform logged 197,047 events. Every other day in the dataset averages 1.8–2.2 million. That's a drop of over 90%. The 7-day rolling z-score comes out to **-18.84**, a value that organic human behavior simply doesn't produce. Roughly 1.8 million events are missing for that date.

**What this means:**
Something failed in the data collection pipeline that day, whether a logging service crash, an ingestion pipeline failure, or a network partition. The data for February 27 is effectively missing from the dataset, not a genuine behavioral signal.

**How it's handled in analysis:**
February 27 is excluded from the Module 7 COVID quasi-experiment pre-period baseline via an explicit `WHERE DATE(event_time) != '2020-02-27'` filter. Including it would artificially lower the pre-COVID average and distort the before/after comparison.

**Real-world note:**
In a production environment, a gap this size would trigger an immediate escalation to the data engineering or platform operations team. An analyst's job is to surface and quantify the gap; root cause diagnosis (server crash, pipeline failure, infrastructure issue) belongs to whoever owns the logging infrastructure. In practice, the analyst would usually already know about it through incident reporting channels before ever spotting the anomaly in a query result. The response is simple: flag it, scope the impact, exclude it from affected analyses, and reference the incident ticket in the documentation.

---

## 3. Platform Price Cap: $2,574.07

**What was found:**
IQR outlier analysis (Module 6) identified a hard ceiling on purchase prices across all major categories: exactly **$2,574.07**. All 100 flagged outlier transactions sit at or within $0.03 of that value, spanning electronics, appliances, computers, accessories, and construction. The maximum price in every major category comes out to the same number.

**What this means:**
This looks like a platform-level price ceiling rather than genuine price fraud or a data error. The most likely mechanism is a round 1,000,000 Kazakhstani Tenge (KZT) transaction limit, converted to USD at the exchange rate in effect around October 2019 (about 388.5 KZT/USD, close to the real historical rate of roughly 383–390 KZT/USD for that period). A third party's separate analysis of this same dataset independently corroborates the explanation, reporting the identical minimum ($0.79) and maximum ($2,574.07) prices, and other users on the dataset's own Kaggle discussion board flagged the same anomaly years ago. The exact business mechanism behind the 1,000,000 KZT figure is still unconfirmed: it could be a specific bank's transaction limit, an AML regulatory threshold, or just an arbitrary round number the merchant's own systems used. See [`price_ceiling_research.md`](price_ceiling_research.md) for the full research trail, including claims that were checked and didn't hold up. IQR outlier flags in this dataset mostly reflect transactions hitting that ceiling rather than anomalous pricing behavior, so outlier rates are better read as "high-value transactions at the ceiling" than as suspicious activity.

A follow-up question got tested directly against the data: could $2,574.07 be only the *first installment* of a larger split payment, with the remainder logged somewhere else? `sql/06_anomaly_detection.sql` Query 6 checked whether the same user and product combination repeatedly hits the cap on a regular, installment-like cadence. It doesn't. Repeats cluster on the same day or session, consistent with buying multiple units in one order, or show irregular gaps unrelated to each other. Either way, there's no sign of the evenly spaced pattern an installment plan would produce. **$2,574.07 should be treated as the true, final recorded price rather than a partial payment** (full test detail in `price_ceiling_research.md`).

**How it's handled:**
Outlier analysis in Module 6 documents this finding and adjusts interpretation accordingly. Price outlier counts by category remain useful for understanding which categories sell at maximum price points most frequently.

---

## 4. Funnel Floor Bias: No Raw Site-Visit Event

**What was found:**
This dataset's `events` table has exactly three `event_type` values: `view`, `cart`, and `purchase`, and every row is tied to a specific `product_id`. There's no event representing a generic site visit, a search, or homepage browsing that never touches a product page. A small gap confirms it: Module 2's total session count (89,693,595, counted from any event at all) comes in 213,976 sessions higher than Module 1's "sessions with a view" count (89,479,619). In other words, roughly 214K sessions have a cart or purchase event but zero logged product views.

**What this means:**
Every conversion rate reported in this project (6.09% overall, and all category and brand conversion rates) is measured **from first product view onward**, rather than from raw site arrival. There's a whole layer of traffic sitting above "viewed a product" that this dataset simply can't see: visitors who searched, browsed the homepage, or bounced without ever opening a product page. The true top-of-funnel conversion rate (site arrival to purchase) is almost certainly lower than 6.09%, but it isn't something this data can compute.

**How it's handled:**
This is a tracking-scope limitation rather than a data error. REES46's tracking script is scoped to product-level interactions because that's what its core product needs (recommendations, cart-abandonment remarketing), not general web analytics. The fix here is interpretive rather than corrective: every conversion metric in this repo should be read as "of the people who engaged with a product, what fraction bought," never as "of all site traffic."
