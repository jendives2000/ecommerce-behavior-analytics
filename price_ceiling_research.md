# Forensic Analysis of the $2,574.07 USD Price Ceiling in the REES46 eCommerce Behavioral Dataset

> **⚠️ Verification notice (added by Claude, not part of Gemini's original report):** This report was produced by Gemini's deep research tool and was independently fact-checked claim by claim — see the "Verification Addendum" near the end of this file for the full breakdown before treating anything below as confirmed fact. Summary: the core exchange-rate math, the GitHub EDA repo's price statistics, and the two cited Kaggle discussion threads were all **confirmed** via direct checks (including a real-browser check for the two items a static fetch couldn't render). The TechnoDom retailer identification and the bank-card-limits table were **not** confirmed — one is directly contradicted by a primary source, the other has no supporting evidence anywhere. A later follow-up test (see the "Follow-up" section further down) also **ruled out** the alternative theory that $2,574.07 is only a partial/first-installment payment — treat it as the true, final recorded price.

## The Multi-Category Price Ceiling Anomaly

Exploratory data analysis of the REES46 "eCommerce behavior data from multi category store" Kaggle dataset — comprising raw clickstream logs from an anonymous multi-category retail platform in the Kazakhstan and Commonwealth of Independent States (CIS) market between October 2019 and April 2020 — uncovers a highly anomalous structural pricing ceiling. Across approximately 411 million behavioral events, including product views, cart additions, cart removals, and completed purchases, the recorded price field for high-value items uniformly truncates at a maximum value of exactly $2,574.07 USD. This ceiling remains perfectly static across completely unrelated product categories, from premium consumer electronics (such as iPhones and luxury laptops) to large household appliances and construction equipment, regardless of the brand or actual market value of the item.

Rather than exhibiting a continuous, long-tailed distribution at the premium end of the retail catalog, the dataset presents a stark mathematical boundary where thousands of diverse products are mapped to the identical price. Empirical analysis of the November 2019 dataset slice reveals a significant statistical accumulation of events in the highest price bin. While intermediate pricing tiers show a steady decay in frequency, the final bin containing the $2,574.07 USD cap exhibits a massive, artificial spike in event counts:

| Price Interval (USD) | Event Count (Nov 2019) | Primary Brands in Interval | Documented Price Status |
|---|---|---|---|
| $2,316.66 – $2,368.14 | 10,733 | Samsung, Apple, LG | Continuous distribution |
| $2,368.14 – $2,419.63 | 10,046 | Apple, Sony | Continuous distribution |
| $2,419.63 – $2,471.11 | 23,540 | Samsung, Apple | Continuous distribution |
| $2,471.11 – $2,522.59 | 13,046 | Apple, Premium Brands | Continuous distribution |
| $2,522.59 – $2,574.07 | 147,369 | Multiple Unrelated Categories | **Rigid, artificial truncation point** |

This behavior cannot be explained by standard retail pricing strategies or consumer fraud. Instead, it strongly suggests a technical data-truncation mechanism or an automated currency conversion constraint operating at the merchant, platform, or exporter level.

## Mathematical Verification of the Currency Conversion Hypothesis

To test the hypothesis that the anomalous $2,574.07 USD cap represents a converted round-number limit in Kazakhstani Tenge (KZT), the currency of the primary market of the retailer, the implied exchange rate must be mathematically calculated and cross-referenced with historical currency data. If the original limit is assumed to be exactly 1,000,000 KZT (one million Tenge), the implied currency exchange rate (R) is derived by dividing the hypothesized KZT limit by the observed USD price ceiling:

**R = 1,000,000 KZT ÷ $2,574.07 USD ≈ 388.4898 KZT/USD**

To establish the validity of this conversion rate, the calculated value of approximately 388.49 KZT/USD must be compared against the actual historical exchange rates managed by the National Bank of Kazakhstan (NBK) during the seven-month data collection window:

| Financial Period Reference | Documented KZT/USD Exchange Rate | Deviation from Calculated Implied Rate |
|---|---|---|
| 2019 Annual Average Rate | ~383.00 KZT/USD | −1.41% |
| **Implied Conversion Rate** | **388.49 KZT/USD** | **0.00%** |
| Specific Rate on October 20, 2019 | 390.29 KZT/USD | +0.46% |
| March 19, 2020 (NBK Foreign Exchange Intervention) | 448.50 KZT/USD | +15.45% |

The minimal variance between the implied rate and the market rates observed in October 2019 provides compelling evidence for the hypothesis. Because the dataset covers a broad period from October 2019 to April 2020, and the price cap remains locked at exactly $2,574.07 USD across all months, the data exporter did not use a dynamic, daily-updated API to perform the conversion. Instead, a static, historical conversion factor of 388.49 KZT/USD was hardcoded into the platform's database query, catalog feed exporter, or localization settings. When premium products with prices exceeding 1,000,000 KZT were processed, the system evaluated them against a domestic limit of one million Tenge, truncated the value, and subsequently applied the frozen conversion factor, printing the identical USD value in the exported CSV logs.

## Kazakhstan Financial Regulations and Transactional Ceilings

*(Verification note: the claims in this section — especially the specific bank card products and limits below — were checked and at least one is confirmed factually wrong. Read with the Verification Addendum in mind.)*

To understand why a domestic cap would exist at precisely 1,000,000 KZT, the regulatory and commercial banking landscape of Kazakhstan during the 2019–2020 period must be examined.

Under the Law of the Republic of Kazakhstan on Financial Monitoring, which establishes anti-money laundering and counter-terrorist financing (AML/CFT) frameworks, financial institutions are subjected to mandatory automated reporting requirements. The report claims transactions equal to or exceeding 1,000,000 KZT are classified as high-risk under Article 4 of the monitoring law, including online payments and cash withdrawals.

The report further claims that payment gateways and commercial banks in Kazakhstan enforced transaction limits centered on the 1,000,000 KZT mark during 2019–2020:

| Institution / Card Product | Operation Type | Documented Cap (KZT) | Associated Fee / Surcharge |
|---|---|---|---|
| Bank CenterCredit IronCard | Single Domestic Transaction | 1,000,000 KZT | Standard rate |
| Bank CenterCredit standard | Card-to-Card (P2P) Single Transfer | 850,000 KZT | Standard rate |
| Altyn Bank / Halyk Bank ATM | Daily Cash Withdrawal Limit | 100,000 KZT | Free of surcharge |
| Eurasian Bank Signature Business | Monthly Fee-Free ATM Cash Limit | 1,000,000 KZT | 0.95% over limit |
| Forte Bank Solo Mastercard | Monthly ATM Cash Withdrawal Limit | 1,000,000 KZT | 1.00% over limit |
| Interbank IBAN Transfers (BCC) | Single Transaction Outward Transfer | 1,000,000 KZT | 0.30% over 300,000 KZT |

**This table's first row is confirmed incorrect** — Bank CenterCredit's own published IronCard terms list the ATM withdrawal limit as ₸3,000,000 **per month**, not 1,000,000 KZT per single transaction. See the Verification Addendum.

The report's narrative continues: these regulatory and technical caps influenced the behavior of online retailers. To prevent payment failures, checkout friction, and AML audit flags, merchants frequently configured their online stores to truncate individual catalog item listings, checkout cart limits, or payment gateway inputs to a maximum value of 1,000,000 KZT.

## Technical Architecture of REES46 and Source Retailer Identification

*(Verification note: the TechnoDom identification below is unsupported by independent research and should not be treated as confirmed. See the Verification Addendum.)*

To determine if the price cap was introduced by the B2B tracking platform itself, the technical data ingestion pipelines of the REES46 Customer Data Platform (CDP) must be analyzed. REES46 functions as an automated marketing engine, collecting behavioral data directly from online storefronts through frontend tracking scripts (e.g., JavaScript) and mobile SDKs, capturing real-time events such as `orderCreated`.

Documentation for the REES46 SDK reportedly confirms that the platform's API maps the price field to a standard floating-point data type without imposing any arbitrary truncation. The report cites an iOS SDK tracking method:

```swift
sdk.track(event: .orderCreated(orderId: "ORDER_ID", totalValue: 33.3, products: [(id: "PRODUCT_1_ID", amount: 3), (id: "PRODUCT_2_ID", amount: 1)]))
```

This is presented as confirming that the tracking payload natively supports unconstrained double-precision float values, with no field-level truncation on price schemas.

Instead, the report argues the platform relies on XML Product Feeds provided by the merchant's e-commerce platform (e.g., Magento, OpenCart, or a custom CMS) to dynamically match catalog metadata with tracked events. If the merchant's underlying database or catalog exporter truncates prices at 1,000,000 KZT, REES46 would merely ingest and display those already-truncated figures.

**The report then claims:** corporate and public-relations records identify TechnoDom (technodom.kz) — a prominent Kazakhstani multi-category electronics and appliance retailer — as one of REES46's primary enterprise customers, and asserts this "proves" the anonymous retailer in this dataset is TechnoDom. **Independent verification found no evidence supporting this specific claim** — see the Verification Addendum.

## Kaggle Community Observations and Academic Literature

*(Verification note: these specific sources could not be confirmed or refuted — the pages require JavaScript to render and returned empty shells when checked. Not confirmed false, just not independently verifiable from here.)*

The report claims the $2,574.07 USD price ceiling has been observed by independent data scientists using this dataset for recommender-system benchmarks and EDA:

- A Kaggle discussion thread titled "Price units," reportedly posted by Martin Fridrich, asking about anomalous units/currency scaling in the price columns.
- A second thread, "Technology Platform Question," reportedly posted by Paul Mills, asking about the tracking script integration and source platform.
- An independent GitHub repository, `suciaulyaputri/EDA-on-E-Commerce-Behaviour-Data`, reportedly documenting a strict minimum price of $0.79 USD and a maximum of exactly $2,574.07 USD after removing zero-price rows, with the following reported descriptive statistics:

| Statistical Metric | Observed Value (USD) | Implied Meaning in KZT (at 388.49 rate) |
|---|---|---|
| Count of Non-Zero Price Events | 3,586,913 | Total interaction volume |
| Mean Event Price | $300.07 | ~116,582 KZT |
| Standard Deviation | $370.41 | ~143,899 KZT |
| Minimum Price | $0.79 | ~307 KZT |
| 25th Percentile | $64.87 | ~25,201 KZT |
| 50th Percentile (Median) | $164.71 | ~63,988 KZT |
| 75th Percentile | $370.41 | ~143,899 KZT |
| Maximum Price | $2,574.07 | 1,000,000 KZT (Truncated) |

The repository itself was confirmed to exist (see Verification Addendum), but these specific statistics were not independently confirmed from its contents.

The report also states that much of the academic literature using this dataset overlooks the truncation artifact — citing a 2026 MDPI *Information* journal paper, "Predicting User Purchases from Clickstream Data: A Comparative Analysis," and a preprint, "RFM-B: A Behavioral Segmentation Framework," both of which reportedly treat price as a continuous variable without addressing the censoring at $2,574.07.

## Categorical Separation of Fact vs. Speculation (Gemini's own framing)

**Gemini's own "confirmed facts" list:**
- The global price ceiling in the Kaggle dataset is exactly $2,574.07 USD.
- The publisher of the Kaggle dataset is Michael Kechinov, crediting the REES46 Marketing Platform.
- REES46 lists TechnoDom as a key enterprise client, confirming the anonymous retailer is TechnoDom. **← Not independently confirmed; see Verification Addendum.**
- The conversion math (1,000,000 KZT ÷ 2,574.07 USD ≈ 388.49 KZT/USD) corresponds closely to documented market exchange rates of late 2019. **← Independently confirmed.**
- Kazakhstan's Law on Financial Monitoring and major banks enforce transaction ceilings around 1,000,000 KZT. **← Partially contradicted; see Verification Addendum.**
- The Kaggle discussion forum contains active threads on currency units and technology integration. **← Not independently confirmed.**

**Gemini's own "speculative inferences" list:**
- The exact business decision leading to the truncation remains an inference; the precise internal code of the merchant's ERP/database cannot be verified through public metadata.
- Whether the fixed 388.49 KZT/USD conversion rate was applied by a legacy export module or a REES46 feed exporter is unconfirmed — both are technically viable and produce identical output.

## Forensic Conclusions (Gemini's original conclusion)

The $2,574.07 USD price ceiling in the REES46 Kaggle dataset is presented as a synthetic artifact from a multi-stage data-processing pipeline: original KZT catalog prices capped at 1,000,000 KZT (influenced by Kazakhstan's financial monitoring threshold and banking transaction caps), then converted to USD using a static rate of 388.49 KZT/USD typical of October 2019, yielding the uniform $2,574.07 ceiling seen across the dataset.

For data scientists and ML engineers, the report frames this as a critical source of bias: any modeling of monetization, price sensitivity, or customer lifetime value (LTV) will be distorted at the upper end of the distribution unless the ceiling is recognized as a censored boundary.

---

## Verification Addendum (added by Claude, independent fact-check)

This section documents what was actually checked and what the result was, so the report above can be read with the right level of trust in each specific claim.

### ✅ Confirmed / independently corroborated

**The exchange-rate math.** Verified independently (before even reading this report) via direct search of historical KZT/USD data: the 2019 annual average was ~383 KZT/USD, and the rate on October 20, 2019 specifically was 390.29 KZT/USD. The implied rate of 388.49 KZT/USD sits almost exactly between these two real data points. Two independent research passes reaching the same number is genuinely solid corroboration — this part of the hypothesis holds up well.

**The GitHub EDA repository's price statistics.** Confirmed via a real-browser check (JS-rendered content, not a static fetch) of `suciaulyaputri/EDA-on-E-Commerce-Behaviour-Data`. The notebook's `df['price'][df["price"] != 0].describe()` output exactly matches what the report claimed: count 3,586,913; mean 300.07; std 370.41; min **0.79**; 25% 64.87; 50% (median) 164.71; 75% 370.41; max **2,574.07**. The notebook's own markdown commentary explicitly states the highest price was 2574.07 and the lowest was 0.79. This is an exact, independently-observed match — the report was accurate on this point.

**The Kaggle discussion threads.** Confirmed via a real-browser check of the dataset's discussion tab. Both threads exist exactly as named: "Price units" by Martin Fridrich (posted ~4 years ago, 1 upvote) and "Technology Platform Question" by Paul Mills (posted ~4 years ago, with a reply from Michael Kechinov — the dataset's actual publisher). The report was accurate on this point too.

### ❌ Directly contradicted by a primary source

**The Bank CenterCredit IronCard limit.** The report claims a "1,000,000 KZT single domestic transaction" limit. Bank CenterCredit's own published card terms (bcc.kz) state the IronCard's ATM withdrawal limit is **₸3,000,000 per month** — a different number, and a different type of limit entirely (monthly withdrawal ceiling, not a single-transaction cap). This is a confirmed factual error in the report, not just an unconfirmed claim.

### ⚠️ Unsupported — should not be treated as fact

**The TechnoDom identification.** The report states with high confidence that "corporate and public-relations records from REES46 identify TechnoDom... as one of their primary enterprise customers," and treats this as proof of the anonymous retailer's identity. Targeted searching found no source anywhere connecting REES46 to TechnoDom. TechnoDom is confirmed to be a real, large Kazakhstani electronics retailer — but its documented digital infrastructure (an AWS case study describing their tech stack) uses AWS ML models, a custom PWA, eSputnik marketing automation, and Cloudflare, with no mention of REES46 at all. This looks like the research tool connected two real, separately-verified facts (TechnoDom is a large Kazakhstan electronics retailer; REES46 serves Kazakhstan/CIS e-commerce clients) into an unsupported specific claim. **Do not repeat "the retailer is TechnoDom" as an established fact in this project's own documentation.**

**The remaining bank card limits table.** Given that one entry (Bank CenterCredit IronCard) is confirmed wrong, and the "Eurasian Bank Signature Business" product could not be found described anywhere with a 1,000,000 KZT limit, the whole table showing four unrelated banks all conveniently landing on exactly 1,000,000 KZT should be treated as unreliable rather than corroborating evidence.

## Follow-up: Partial-Payment / Installment Theory — Tested Directly Against the Data (added by Claude + user, 2026-07-08)

One question the exchange-rate hypothesis alone couldn't answer: does $2,574.07 represent the *true, final* amount a customer paid (a hard ceiling nobody can exceed), or could it be only the *first installment* of a larger split payment — with the remainder processed outside this tracking data and never logged? Both mechanisms would produce the exact same repeated-cap pattern in the data, so the exchange-rate math alone couldn't distinguish between them.

**The test:** if installments were happening, the same `(user_id, product_id)` pair should hit the cap repeatedly, spread across a regular, plan-like cadence (e.g., roughly every 30 days). If it's a simple hard ceiling, any repeats should look like ordinary behavior — buying multiple units in one order, or unrelated repeat purchases over time — not a structured payment schedule.

**Results** (`sql/06_anomaly_detection.sql`, Query 6, run against the full 411M-row dataset):

- 930 total capped transactions across 689 distinct users — average 1.35 repeats per user. Modest repetition, far short of what a widespread installment scheme would produce.
- The large majority of same-user, same-product repeats happen on the **same day**, frequently in the **same session** (e.g., user 610295394 bought product 100085989 four times in one session, one day — almost certainly 4 units of the same item in one order).
- Where repeat gaps exist, they're irregular — 73, 82, 63, 22, 18, 17, 24 days — no shared interval, nothing resembling a fixed installment cadence.
- The single most-repeated product (1802024) is spread across dozens of *different* users, each with their own unrelated, random gap — consistent with a generically popular high-ticket item bought by many separate customers, not one person's payment history.

**Conclusion:** the evidence leans clearly against the partial-payment/installment theory. The repeat pattern is much better explained by ordinary multi-unit or repeat purchases than by hidden, unlogged installment charges. This isn't airtight proof — actual payment-processor records aren't available, only browsing/purchase events — but the specific signature installments would produce (regular, evenly-spaced repeats for the same user+product) is absent from the data, while the signature a simple hard ceiling would produce (same-session clustering, irregular unrelated gaps) is exactly what's there.

**Practical takeaway:** treat $2,574.07 as the true, final recorded price for capped transactions, not a partial payment. Revenue totals in this project are not being systematically understated due to hidden installment charges.

---

### Bottom-line conclusion

**The core numeric hypothesis — a round 1,000,000 KZT limit converted via the ~388.49 KZT/USD rate in effect around October 2019 — remains a well-supported, evidence-backed explanation for the $2,574.07 price cap.** This is corroborated by four independent, verifiable data points: real historical exchange-rate data, an exact match to a third party's own EDA statistics on this dataset ($0.79 min / $2,574.07 max, confirmed via direct browser check), confirmation that this anomaly was independently noticed by other users on the dataset's own Kaggle discussion board years ago (the "Price units" thread), and a direct data test ruling out the partial-payment alternative (see above).

**However, the elaborate supporting narrative Gemini built on top of that solid foundation does not hold up equally well.** The specific named retailer (TechnoDom) is unsupported by any source found despite targeted searching, and the bank transaction-limits table contains at least one directly falsified figure (Bank CenterCredit's real IronCard limit is ₸3,000,000/month, not the claimed 1,000,000 KZT single-transaction cap).

**The pattern worth remembering:** Gemini's report was accurate exactly where it was doing genuine, checkable retrieval — pulling real numbers from a real notebook, finding real discussion thread titles — and became unreliable exactly where it needed to connect weaker, more indirect signals into a confident-sounding causal story (which specific company, which specific bank product). That's a useful, general lesson for evaluating AI research output: verify hardest at the exact point where the narrative stops quoting a source directly and starts synthesizing a conclusion. The right takeaway for this project's documentation is to keep the exchange-rate hypothesis exactly as unconfirmed-but-now-well-corroborated, treat the partial-payment question as tested and resolved, and to not add the TechnoDom identification or the bank-limits table to the project at all.
