# Workflow: Domain Context Research

## Purpose

This document establishes the business and market context for the REES46 dataset before any module interpretation. Without it, findings like "construction category leads at 8.24% conversion" are uninterpretable. All subsequent analytical conclusions should be read against this context.

**Sources:** Gemini web research + independent Claude web search, cross-referenced. Confidence levels noted where findings are unverified.

---

## 1. What Is REES46?

REES46 is a **B2B SaaS Customer Data Platform (CDP)** for e-commerce and retail, founded in 2013 by Michael Kechinov. Its products include personalized recommendation engines, behavior-triggered marketing automation, and predictive search tooling. REES46 does not operate a retail store — it sells software to online merchants.

**Implication for this dataset:** The data does not come from REES46. It comes from an **anonymous external client store** that integrated the REES46 tracking script into its platform. REES46 published this client's clickstream data through its "Open CDP" open-source initiative. The client's identity is deliberately not named.

---

## 2. Geography and Market

The store most likely operates in **Kazakhstan** or the broader CIS (Commonwealth of Independent States) region.

**Evidence — brand list analysis:**

| Brand | Origin | Significance |
|-------|--------|-------------|
| Samsung, Apple, Xiaomi, Huawei, Oppo, Sony, LG | Global | Present everywhere — no regional signal |
| Artel | Uzbekistan | Dominant appliance/electronics brand across Central Asia, especially Kazakhstan |
| Cordiant | Russia | Leading Russian tire manufacturer, widely distributed in CIS |
| Redmond | Russia | Popular for multi-cookers and smart kitchen appliances in CIS |
| Vitek | Russia | Budget small appliances, CIS private label |
| Polaris | Russia | Major appliance distributor across CIS |
| ARG | Kazakhstan (probable) | Strongly suggested to be the private label of Alser, a major Kazakhstan electronics chain with 140+ stores in 52 cities |

The combination of Artel, Cordiant, Redmond, Vitek, Polaris, and ARG points to Kazakhstan or adjacent Central Asian markets. **Alser.kz** is a verified major multi-category retailer in Kazakhstan matching the dataset profile (electronics, appliances, large assortment). The ARG–Alser connection is plausible but not publicly confirmed — treat as a strong hypothesis, not a fact.

**Confidence: High (Kazakhstan CIS), Medium (Alser specifically).**

---

## 3. Category Taxonomy

Category codes in the dataset are machine-translated from Russian retail database schemas. The literal English translations obscure their actual meaning:

| Dataset category | Russian original | Actual retail meaning |
|-----------------|-----------------|----------------------|
| `construction` | Строительство (Stroitelstvo) | **DIY & Home Improvement** — power tools, plumbing, electrical supplies, paint, hardware, building materials |
| `country_yard` | Дача, сад и огород | **Garden, Dacha & Outdoor** — gardening tools, seasonal outdoor furniture, fertilizers, dacha maintenance supplies |
| `appliances` | Бытовая техника | Household appliances (large and small) |
| `auto` | Автотовары | Automotive supplies — tires, car accessories, fluids |
| `electronics` | Электроника | Consumer electronics |
| `furniture` | Мебель | Furniture |

**The "construction" finding reinterpreted:** The category leads conversion at 8.24% (vs 6.09% overall) because DIY/Home Improvement shoppers arrive with specific project-driven intent. They are looking for a specific fitting, tool, or material — not browsing. When they find it, they buy it. This is behaviorally consistent and expected. It is not a surprising anomaly.

**The "country_yard" finding:** The dacha is a central cultural institution in CIS societies — a seasonal countryside plot. "country_yard" is the gardening/dacha category, equivalent to a Home Depot garden center section. Low conversion (2.76%) is consistent with seasonal and discretionary outdoor products.

---

## 4. The "Unknown" Category (NULL category_code)

16.8 million view sessions have a NULL `category_code`. This is **a systematic platform design choice, not a data quality error.**

**Why it happens:**
1. **Accessories and parts:** Mobile phone cases, cables, chargers, and replacement parts are deliberately excluded from the primary taxonomy to keep recommendation algorithms focused on high-value parent products.
2. **Third-party seller uploads:** On marketplace platforms, third-party merchants uploading inventory via XML/CSV feeds often fail to map their SKUs to the platform's taxonomy. The `category_id` (numeric) is recorded but `category_code` (text) remains blank.
3. **Legacy catalog sync:** Some SKUs from older ERP/inventory systems are not mapped when synchronized with the REES46 tracking layer.

**Analytical treatment:** Do not conflate "unknown" with missing data. These are real products — likely accessories, unbranded items, and generic parts. For category-level analysis, label them "Accessories/Unclassified" rather than dropping them or treating them as errors. Their 4.03% conversion rate is meaningful.

---

## 5. Platform Behavior and Data Quirks

These are documented behaviors of the source platform that affect how raw events should be interpreted.

### 5a. Direct checkout (view → purchase, no cart)
Some purchases happen without a preceding cart event in the same session. Our Module 1 data confirmed **530,292 sessions** with a purchase event but no cart event. This is a real platform feature — a "buy now" / 1-click checkout path, not a data anomaly. Funnel analysis that assumes a rigid view→cart→purchase sequence will undercount purchase intent.

### 5b. Multiple purchase events in one session
A single session can contain multiple `purchase` events. This represents a **multi-item order**, not multiple transactions. For average order value (AOV) and basket analysis, group concurrent purchase events by session, not by individual event row.

### 5c. Session UUID behavior
The `user_session` UUID resets when a user returns after a period of inactivity (typically ~30 minutes). A single user may have many sessions across the 7-month dataset. Do not confuse `user_session` (ephemeral) with `user_id` (persistent).

### 5d. Possible logging outages
Gemini's research identified two specific dates — November 15, 2019 and January 2, 2020 — as potential logging outage days with zero or near-zero transaction records. **This has not been independently verified.** Before flagging any date-level anomaly in Module 6 (Anomaly Detection) or Module 7 (COVID Quasi-Experiment), run a daily event count query to identify genuine gaps.

**Verification query:**
```sql
SELECT
  DATE(event_time) AS event_date,
  COUNT(*) AS events
FROM `instant-form-500912-n7.rees46.events`
GROUP BY event_date
ORDER BY events ASC
LIMIT 20;
```

---

## 6. COVID-19 Context for Module 7

Module 7 treats March–April 2020 as the "COVID onset" period. Kazakhstan's timeline makes this quasi-experiment unusually precise:

| Date | Event |
|------|-------|
| March 13, 2020 | First confirmed COVID-19 case in Kazakhstan (Almaty) |
| March 15, 2020 | President Tokayev declares state of emergency |
| March 16, 2020 | Nationwide lockdown begins |
| March 19, 2020 | Strict quarantine imposed on Almaty and Astana (major cities) |
| April 2020 | Full lockdown continues through the month |

The dataset's March 2020 data captures the behavioral shock from the exact day COVID entered the country. The quasi-experiment is not measuring a vague "pandemic period" — it is measuring the effect of a sudden, government-declared national emergency on consumer e-commerce behavior, with a clean pre-period baseline of 5 months.

This strengthens the validity of Module 7's z-test. The treatment event (lockdown) is sharp and dateable, not gradual.

---

## 7. Analytical Implications by Module

| Module | Implication |
|--------|-------------|
| M1 — Funnel | The 530,292 direct-purchase sessions are a legitimate behavior, not missing data. Report them separately as "direct checkout" alongside the standard funnel. |
| M2 — Session Analytics | Multi-purchase events in one session = one order. Session duration is bounded by UUID reset logic (~30 min inactivity). |
| M3 — RFM | `user_id` is persistent and reliable for segmentation. `price` is captured at event time (not a fixed catalog price). |
| M5 — Category & Brand | Reclassify `construction` as "DIY/Home Improvement" in all outputs. Reclassify `country_yard` as "Garden/Outdoor." Treat `unknown` as "Accessories/Unclassified." |
| M6 — Anomaly Detection | Before flagging date-level purchase anomalies, verify against the logging outage dates. A zero-transaction day may be a data gap, not a behavioral anomaly. |
| M7 — COVID Quasi-Experiment | The treatment boundary is March 13–16, 2020 (first case → lockdown), not just "March 1." Consider a finer pre/post split at March 16 for the statistical test. |
