# Overview Explainability Tooltips Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a definitional explainability tooltip to each of the 8 KPI cards on the Overview page, following the DAX-measure-driven pattern approved in `docs/planning/specs/2026-07-16-explainability-tooltips-design.md`.

**Architecture:** Each KPI card gets one new DAX measure (`<Card Title> Tooltip`) that pulls its definition live via `LOOKUPVALUE` against `DataDictionary_Measures`, adds a short live-computed calculation-context line, and — only where genuinely relevant — one conditional data-quality sentence. Each measure is bound to an `htmlContent` visual on its own new hidden `Tooltip`-type page, wired to the source card via the `visualTooltip` VCO. No native hover-tooltip or Sentence-format work is in this plan — that mechanism is for charts, out of scope for Overview's cards.

**Tech Stack:** Power BI PBIP/PBIR file format (hand-authored JSON/TMDL), `powerbi-report-author` CLI (validate), `powerbi-desktop` CLI (status/reload/screenshot), DAX.

## Global Constraints

- New measure naming: `<Card Title> Tooltip`, matching the KPI card's displayed title (not necessarily the raw bound measure's name — e.g. the COVID card displays "COVID Impact on Conversion" even though it's bound to `COVID Session Conversion Lift`).
- New measure `displayFolder`: `Tooltips\Overview` for every measure in this plan.
- New page naming: `overview-<topic>-tooltip`.
- New page schema: `"displayOption": "FitToPage", "height": 300, "width": 400, "visibility": "HiddenInViewMode", "type": "Tooltip"` — copied from the existing `funnel-floor-bias-tooltip` / `price-cap-tooltip` pages.
- New tooltip visual position (matches existing precedent exactly): `x: 18.717948717948719, y: 26.666666666666668, z: 0, height: 263.84615384615387, width: 362.5641025641026, tabOrder: 0`.
- HTML style for every tooltip measure's returned string: `font-family:"Segoe UI Light","Segoe UI",sans-serif;font-weight:300;color:#FFFFFF;font-size:18px;text-align:justify` wrapping `<p>` paragraphs (first `margin:0`, subsequent `margin:8px 0 0 0`) — bumped from the original 13px (matching `Funnel Floor Bias Tooltip`) after Task 2's review; the smaller size left too much empty space on the 300x400 canvas. Tasks 1-2 were retrofitted to match (commit `f16efe7`).
- Content rule: tooltip text must not repeat a number or sentence already visible elsewhere on the Overview page (including the card's own badge, where applicable).
- Data-quality tie-in: one conditional sentence, only when the measure genuinely touches one of the 4 documented findings (Funnel Floor Bias, Category Taxonomy Anomaly, Platform Price Cap, Logging Gap) — omitted otherwise.
- Verification loop for every task: `powerbi-report-author validate --format text "dashboards/ecommerce_behavior_analytics.Report"` must hold at exactly one more warning than the previous task left off at, same error/warning categories (see Amendment below — NOT the original flat "23 warnings") → `powerbi-desktop reload --pid <PID>` → `powerbi-desktop screenshot <new-page-id> --pid <PID>` → pause for user review → commit. Get `<PID>` fresh from `powerbi-desktop status` at the start of each task (don't reuse a stale value from an earlier task or session).
- Screenshotting must target the new **tooltip page itself** (e.g. `overview-total-events-tooltip`), not the Overview page — a static screenshot of Overview cannot show a hover-triggered tooltip; the tooltip page is a real, directly addressable page.
- One task = one KPI card. Commit after each task. Pause for the user's review of the screenshot before starting the next task — do not batch multiple cards ahead of review.

## Amendments (after Task 1)

- **Measure creation is two-step, not one.** Hand-editing `_Measures.tmdl` and running `powerbi-desktop reload` does **not** load a new DAX measure into the live semantic model, even though the reload bridge's manifest claims `reloadModelDefinition` defaults to true. Confirmed via `EVALUATE {[<new measure>]}` against the live model through the `powerbi-modeling-mcp` MCP connection returning "measure not found" after a hand-edit + reload. Fix: after hand-editing the TMDL text (Step 1 of each task, for git history), also call `measure_operations` (operation `Create`) via that same MCP connection with matching name/expression/displayFolder/lineageTag, so the measure is live before reload/screenshot. Do **not** use `database_operations` `ExportToTmdlFolder` to sync — it silently regenerates `cultures/en-US.tmdl` (Power BI's auto-generated Q&A linguistic metadata) from ~23,000 lines down to almost nothing.
- **Validator baseline climbs by 1 warning per task, not flat.** Each new tooltip page's `htmlContent443BE3AD55E043BF878BED274D3A6855` visual adds one more (already-tolerated) `PBIR_VISUAL_TYPE_UNKNOWN` warning. Confirmed benign both times. Track "previous task's count + 1, same categories" as the real gate.
- **Descriptions rewritten in plain language.** All 8 Overview KPI measures' `///` doc-comments (the `DataDictionary_Measures[Description]` source every tooltip's `LOOKUPVALUE` reads) were rewritten from data-analyst voice to stakeholder-facing plain language after Task 1's review (commit `3c5238f`). No task's DAX code needs to change for this — `LOOKUPVALUE` reads whatever the current description is at evaluation time.
- **After updating a measure's `description` via MCP, refresh `DataDictionary_Measures`.** It's a calculated table (`INFO.VIEW.MEASURES()`) that does not auto-refresh on metadata changes. Run `model_operations` (operation `RefreshWithXMLA`, `refreshType: Full`, `tableName: DataDictionary_Measures`) or the tooltip will keep showing stale text.

## File Structure

- Modify: `dashboards/ecommerce_behavior_analytics.SemanticModel/definition/tables/_Measures.tmdl` — one new measure appended per task.
- Create: `dashboards/ecommerce_behavior_analytics.Report/definition/pages/<new-page>/page.json` — one per task.
- Create: `dashboards/ecommerce_behavior_analytics.Report/definition/pages/<new-page>/visuals/<visual-id>/visual.json` — one per task.
- Modify: `dashboards/ecommerce_behavior_analytics.Report/definition/pages/pages.json` — append the new page name to `pageOrder`, once per task.
- Modify: `dashboards/ecommerce_behavior_analytics.Report/definition/pages/overview/visuals/<source-card-id>/visual.json` — add or repoint the `visualTooltip` VCO, once per task.

No test framework exists in this project for PBIR authoring; the "test" for every task is the validate → reload → screenshot loop described in Global Constraints.

---

### Task 1: Total Events Tooltip

**Files:**
- Modify: `dashboards/ecommerce_behavior_analytics.SemanticModel/definition/tables/_Measures.tmdl`
- Create: `dashboards/ecommerce_behavior_analytics.Report/definition/pages/overview-total-events-tooltip/page.json`
- Create: `dashboards/ecommerce_behavior_analytics.Report/definition/pages/overview-total-events-tooltip/visuals/beafbd587fa5d5f7ca79/visual.json`
- Modify: `dashboards/ecommerce_behavior_analytics.Report/definition/pages/pages.json`
- Modify: `dashboards/ecommerce_behavior_analytics.Report/definition/pages/overview/visuals/a79e591fb3177c382625/visual.json`

**Interfaces:**
- Consumes: `DataDictionary_Measures[Description]` / `DataDictionary_Measures[Name]` (existing calculated table), `[Total Events]`, `[Purchasing Users]` (existing measures).
- Produces: measure `'Total Events Tooltip'` in `_Measures`; page `overview-total-events-tooltip`.

- [ ] **Step 1: Add the `Total Events Tooltip` measure**

Append to the end of `_Measures.tmdl`, immediately before the `column Value` block (i.e. after the `'Funnel Floor Bias Tooltip'` measure):

```
	/// Explainability tooltip for the Total Events KPI card - definition pulled live from the Data Dictionary, paired with a per-purchasing-user ratio for scale. Bind to an HTML Content visual on the 'overview-total-events-tooltip' page.
	measure 'Total Events Tooltip' =
			VAR Def = LOOKUPVALUE(DataDictionary_Measures[Description], DataDictionary_Measures[Name], "Total Events")
			VAR EventsPerBuyer = FORMAT(DIVIDE([Total Events], [Purchasing Users]), "0")
			RETURN
			    "<div style='font-family:""Segoe UI Light"",""Segoe UI"",sans-serif;font-weight:300;color:#FFFFFF;font-size:13px;text-align:justify;'>" &
			        "<p style='margin:0;'>" & Def & "</p>" &
			        "<p style='margin:8px 0 0 0;'>That works out to roughly " & EventsPerBuyer & " tracked events for every user who went on to purchase.</p>" &
			    "</div>"
		displayFolder: Tooltips\Overview
		lineageTag: 31a57712-ade3-4b0f-9726-3cd631c6df72

```

- [ ] **Step 2: Create the tooltip page**

Create `dashboards/ecommerce_behavior_analytics.Report/definition/pages/overview-total-events-tooltip/page.json`:

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/item/report/definition/page/2.1.0/schema.json",
  "name": "overview-total-events-tooltip",
  "displayName": "Total Events",
  "displayOption": "FitToPage",
  "height": 300,
  "width": 400,
  "visibility": "HiddenInViewMode",
  "type": "Tooltip"
}
```

- [ ] **Step 3: Create the tooltip's HTML Content visual**

Create `dashboards/ecommerce_behavior_analytics.Report/definition/pages/overview-total-events-tooltip/visuals/beafbd587fa5d5f7ca79/visual.json`:

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/item/report/definition/visualContainer/2.10.0/schema.json",
  "name": "beafbd587fa5d5f7ca79",
  "position": {
    "x": 18.717948717948719,
    "y": 26.666666666666668,
    "z": 0,
    "height": 263.84615384615387,
    "width": 362.5641025641026,
    "tabOrder": 0
  },
  "visual": {
    "visualType": "htmlContent443BE3AD55E043BF878BED274D3A6855",
    "query": {
      "queryState": {
        "content": {
          "projections": [
            {
              "field": {
                "Measure": {
                  "Expression": {
                    "SourceRef": {
                      "Entity": "_Measures"
                    }
                  },
                  "Property": "Total Events Tooltip"
                }
              },
              "queryRef": "_Measures.Total Events Tooltip",
              "nativeQueryRef": "Total Events Tooltip"
            }
          ]
        }
      }
    },
    "drillFilterOtherVisuals": true
  }
}
```

- [ ] **Step 4: Register the new page**

In `dashboards/ecommerce_behavior_analytics.Report/definition/pages/pages.json`, add `"overview-total-events-tooltip"` to the end of `pageOrder`:

```json
  "pageOrder": [
    "overview",
    "funnel",
    "category-brand",
    "customer-segments",
    "covid-impact",
    "data-dictionary",
    "cohort-detail",
    "anomaly-detail",
    "funnel-floor-bias-tooltip",
    "price-cap-tooltip",
    "overview-total-events-tooltip"
  ],
```

- [ ] **Step 5: Wire the Total Events card to the new tooltip**

In `dashboards/ecommerce_behavior_analytics.Report/definition/pages/overview/visuals/a79e591fb3177c382625/visual.json`, the `visualContainerObjects` object currently has `title`, `spacing`, `background`, `border`, `visualHeader` keys but no `visualTooltip` key. Add one:

```json
      "visualTooltip": [
        {
          "properties": {
            "show": {
              "expr": {
                "Literal": {
                  "Value": "true"
                }
              }
            },
            "section": {
              "expr": {
                "Literal": {
                  "Value": "'overview-total-events-tooltip'"
                }
              }
            }
          }
        }
      ],
```

Insert it as a new key inside the existing `"visualContainerObjects": { ... }` object (order among sibling keys doesn't matter).

- [ ] **Step 6: Validate**

Run: `powerbi-report-author validate --format text "dashboards/ecommerce_behavior_analytics.Report"`
Expected: same baseline as before this task — 4 errors, 23 warnings. No new error/warning categories.

- [ ] **Step 7: Reload and screenshot**

Run: `powerbi-desktop status` — read the current `pid`.
Run: `powerbi-desktop reload --pid <PID>`
Run: `powerbi-desktop screenshot overview-total-events-tooltip --pid <PID>`
Expected: PNG shows the tooltip page rendering the two-paragraph definition + ratio sentence in white `Segoe UI Light` text.

- [ ] **Step 8: Pause for review**

Show the screenshot to the user. Wait for approval before starting Task 2.

- [ ] **Step 9: Commit**

```bash
git add dashboards/ecommerce_behavior_analytics.SemanticModel/definition/tables/_Measures.tmdl dashboards/ecommerce_behavior_analytics.Report/definition/pages/overview-total-events-tooltip dashboards/ecommerce_behavior_analytics.Report/definition/pages/pages.json dashboards/ecommerce_behavior_analytics.Report/definition/pages/overview/visuals/a79e591fb3177c382625/visual.json
git commit -m "feat: add Total Events explainability tooltip"
```

---

### Task 2: Purchasing Users Tooltip

**Files:**
- Modify: `dashboards/ecommerce_behavior_analytics.SemanticModel/definition/tables/_Measures.tmdl`
- Create: `dashboards/ecommerce_behavior_analytics.Report/definition/pages/overview-purchasing-users-tooltip/page.json`
- Create: `dashboards/ecommerce_behavior_analytics.Report/definition/pages/overview-purchasing-users-tooltip/visuals/50fd66b4c5a1b25db6c3/visual.json`
- Modify: `dashboards/ecommerce_behavior_analytics.Report/definition/pages/pages.json`
- Modify: `dashboards/ecommerce_behavior_analytics.Report/definition/pages/overview/visuals/89bff7e7cfb4a0624b0e/visual.json`

**Interfaces:**
- Consumes: `DataDictionary_Measures[Description]`/`[Name]`, `[Overall Conversion Rate]` (existing measure).
- Produces: measure `'Purchasing Users Tooltip'`; page `overview-purchasing-users-tooltip`.

- [ ] **Step 1: Add the `Purchasing Users Tooltip` measure**

Append to `_Measures.tmdl` (after the measure added in Task 1):

```
	/// Explainability tooltip for the Purchasing Users KPI card - definition pulled live from the Data Dictionary, paired with the conversion rate these users represent. Bind to an HTML Content visual on the 'overview-purchasing-users-tooltip' page.
	measure 'Purchasing Users Tooltip' =
			VAR Def = LOOKUPVALUE(DataDictionary_Measures[Description], DataDictionary_Measures[Name], "Purchasing Users")
			VAR ConvRate = FORMAT([Overall Conversion Rate], "0.0%")
			RETURN
			    "<div style='font-family:""Segoe UI Light"",""Segoe UI"",sans-serif;font-weight:300;color:#FFFFFF;font-size:13px;text-align:justify;'>" &
			        "<p style='margin:0;'>" & Def & "</p>" &
			        "<p style='margin:8px 0 0 0;'>These are the users behind the " & ConvRate & " view-to-purchase rate shown elsewhere on this page.</p>" &
			    "</div>"
		displayFolder: Tooltips\Overview
		lineageTag: 5256b61a-d64a-4b67-86cb-c15e12fcc1ad

```

- [ ] **Step 2: Create the tooltip page**

Create `dashboards/ecommerce_behavior_analytics.Report/definition/pages/overview-purchasing-users-tooltip/page.json`:

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/item/report/definition/page/2.1.0/schema.json",
  "name": "overview-purchasing-users-tooltip",
  "displayName": "Purchasing Users",
  "displayOption": "FitToPage",
  "height": 300,
  "width": 400,
  "visibility": "HiddenInViewMode",
  "type": "Tooltip"
}
```

- [ ] **Step 3: Create the tooltip's HTML Content visual**

Create `dashboards/ecommerce_behavior_analytics.Report/definition/pages/overview-purchasing-users-tooltip/visuals/50fd66b4c5a1b25db6c3/visual.json`:

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/item/report/definition/visualContainer/2.10.0/schema.json",
  "name": "50fd66b4c5a1b25db6c3",
  "position": {
    "x": 18.717948717948719,
    "y": 26.666666666666668,
    "z": 0,
    "height": 263.84615384615387,
    "width": 362.5641025641026,
    "tabOrder": 0
  },
  "visual": {
    "visualType": "htmlContent443BE3AD55E043BF878BED274D3A6855",
    "query": {
      "queryState": {
        "content": {
          "projections": [
            {
              "field": {
                "Measure": {
                  "Expression": {
                    "SourceRef": {
                      "Entity": "_Measures"
                    }
                  },
                  "Property": "Purchasing Users Tooltip"
                }
              },
              "queryRef": "_Measures.Purchasing Users Tooltip",
              "nativeQueryRef": "Purchasing Users Tooltip"
            }
          ]
        }
      }
    },
    "drillFilterOtherVisuals": true
  }
}
```

- [ ] **Step 4: Register the new page**

Add `"overview-purchasing-users-tooltip"` to the end of `pageOrder` in `pages.json` (after `"overview-total-events-tooltip"`).

- [ ] **Step 5: Wire the Purchasing Users card to the new tooltip**

In `dashboards/ecommerce_behavior_analytics.Report/definition/pages/overview/visuals/89bff7e7cfb4a0624b0e/visual.json`, add a `visualTooltip` key inside the existing `visualContainerObjects` object:

```json
      "visualTooltip": [
        {
          "properties": {
            "show": {
              "expr": {
                "Literal": {
                  "Value": "true"
                }
              }
            },
            "section": {
              "expr": {
                "Literal": {
                  "Value": "'overview-purchasing-users-tooltip'"
                }
              }
            }
          }
        }
      ],
```

- [ ] **Step 6: Validate**

Run: `powerbi-report-author validate --format text "dashboards/ecommerce_behavior_analytics.Report"`
Expected: 4 errors, 23 warnings — unchanged.

- [ ] **Step 7: Reload and screenshot**

Run: `powerbi-desktop status` — read the current `pid`.
Run: `powerbi-desktop reload --pid <PID>`
Run: `powerbi-desktop screenshot overview-purchasing-users-tooltip --pid <PID>`
Expected: PNG shows the definition + conversion-rate sentence.

- [ ] **Step 8: Pause for review**

Show the screenshot to the user. Wait for approval before starting Task 3.

- [ ] **Step 9: Commit**

```bash
git add dashboards/ecommerce_behavior_analytics.SemanticModel/definition/tables/_Measures.tmdl dashboards/ecommerce_behavior_analytics.Report/definition/pages/overview-purchasing-users-tooltip dashboards/ecommerce_behavior_analytics.Report/definition/pages/pages.json dashboards/ecommerce_behavior_analytics.Report/definition/pages/overview/visuals/89bff7e7cfb4a0624b0e/visual.json
git commit -m "feat: add Purchasing Users explainability tooltip"
```

---

### Task 3: Overall Conversion Rate Tooltip (repoints the existing Funnel Floor Bias wiring)

**Files:**
- Modify: `dashboards/ecommerce_behavior_analytics.SemanticModel/definition/tables/_Measures.tmdl`
- Create: `dashboards/ecommerce_behavior_analytics.Report/definition/pages/overview-conversion-rate-tooltip/page.json`
- Create: `dashboards/ecommerce_behavior_analytics.Report/definition/pages/overview-conversion-rate-tooltip/visuals/20bc811b6e942eb7b8ee/visual.json`
- Modify: `dashboards/ecommerce_behavior_analytics.Report/definition/pages/pages.json`
- Modify: `dashboards/ecommerce_behavior_analytics.Report/definition/pages/overview/visuals/395ee0f115445cf6890e/visual.json`

**Interfaces:**
- Consumes: `DataDictionary_Measures[Description]`/`[Name]`, `[Overall Conversion Rate]`.
- Produces: measure `'Overall Conversion Rate Tooltip'`; page `overview-conversion-rate-tooltip`.

**Note:** the Overall Conversion Rate card (`395ee0f115445cf6890e`) currently points its `visualTooltip` section at `funnel-floor-bias-tooltip`. This task's new measure folds the floor-bias caveat in as its own data-quality sentence, so this card's `visualTooltip.section` is **repointed** to the new page instead of left as-is. The `funnel-floor-bias-tooltip` page and its `'Funnel Floor Bias Tooltip'` measure are left in place, unused for now — confirmed via search that no other visual references that page, so nothing else breaks. It's a reasonable candidate to rewire onto the Funnel page's own funnel chart in a later page's rollout, but that's not part of this task.

- [ ] **Step 1: Add the `Overall Conversion Rate Tooltip` measure**

Append to `_Measures.tmdl`:

```
	/// Explainability tooltip for the Overall Conversion Rate KPI card - definition pulled live from the Data Dictionary, folding in the Funnel Floor Bias data quality finding since it directly caps what this rate can mean. Replaces the standalone Funnel Floor Bias Tooltip binding on this card. Bind to an HTML Content visual on the 'overview-conversion-rate-tooltip' page.
	measure 'Overall Conversion Rate Tooltip' =
			VAR Def = LOOKUPVALUE(DataDictionary_Measures[Description], DataDictionary_Measures[Name], "Overall Conversion Rate")
			VAR OverallRate = FORMAT([Overall Conversion Rate], "0.0%")
			RETURN
			    "<div style='font-family:""Segoe UI Light"",""Segoe UI"",sans-serif;font-weight:300;color:#FFFFFF;font-size:13px;text-align:justify;'>" &
			        "<p style='margin:0;'>" & Def & "</p>" &
			        "<p style='margin:8px 0 0 0;'>Note: this is measured from first product view onward. About 214,000 sessions have a cart or purchase event but zero logged views - true top-of-funnel conversion is almost certainly lower than " & OverallRate & ", but isn't computable from this data. See Data Quality Notes for detail.</p>" &
			    "</div>"
		displayFolder: Tooltips\Overview
		lineageTag: c86b68d3-2aaf-4374-91aa-f58f4b2d934d

```

- [ ] **Step 2: Create the tooltip page**

Create `dashboards/ecommerce_behavior_analytics.Report/definition/pages/overview-conversion-rate-tooltip/page.json`:

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/item/report/definition/page/2.1.0/schema.json",
  "name": "overview-conversion-rate-tooltip",
  "displayName": "Overall Conversion Rate",
  "displayOption": "FitToPage",
  "height": 300,
  "width": 400,
  "visibility": "HiddenInViewMode",
  "type": "Tooltip"
}
```

- [ ] **Step 3: Create the tooltip's HTML Content visual**

Create `dashboards/ecommerce_behavior_analytics.Report/definition/pages/overview-conversion-rate-tooltip/visuals/20bc811b6e942eb7b8ee/visual.json`:

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/item/report/definition/visualContainer/2.10.0/schema.json",
  "name": "20bc811b6e942eb7b8ee",
  "position": {
    "x": 18.717948717948719,
    "y": 26.666666666666668,
    "z": 0,
    "height": 263.84615384615387,
    "width": 362.5641025641026,
    "tabOrder": 0
  },
  "visual": {
    "visualType": "htmlContent443BE3AD55E043BF878BED274D3A6855",
    "query": {
      "queryState": {
        "content": {
          "projections": [
            {
              "field": {
                "Measure": {
                  "Expression": {
                    "SourceRef": {
                      "Entity": "_Measures"
                    }
                  },
                  "Property": "Overall Conversion Rate Tooltip"
                }
              },
              "queryRef": "_Measures.Overall Conversion Rate Tooltip",
              "nativeQueryRef": "Overall Conversion Rate Tooltip"
            }
          ]
        }
      }
    },
    "drillFilterOtherVisuals": true
  }
}
```

- [ ] **Step 4: Register the new page**

Add `"overview-conversion-rate-tooltip"` to the end of `pageOrder` in `pages.json`.

- [ ] **Step 5: Repoint the Overall Conversion Rate card's tooltip**

In `dashboards/ecommerce_behavior_analytics.Report/definition/pages/overview/visuals/395ee0f115445cf6890e/visual.json`, the existing `visualContainerObjects.visualTooltip` block reads:

```json
      "visualTooltip": [
        {
          "properties": {
            "show": {
              "expr": {
                "Literal": {
                  "Value": "true"
                }
              }
            },
            "section": {
              "expr": {
                "Literal": {
                  "Value": "'funnel-floor-bias-tooltip'"
                }
              }
            }
          }
        }
      ]
```

Change the `section` value from `'funnel-floor-bias-tooltip'` to `'overview-conversion-rate-tooltip'`. Every other key/value in the file stays the same.

- [ ] **Step 6: Validate**

Run: `powerbi-report-author validate --format text "dashboards/ecommerce_behavior_analytics.Report"`
Expected: 4 errors, 23 warnings — unchanged.

- [ ] **Step 7: Reload and screenshot**

Run: `powerbi-desktop status` — read the current `pid`.
Run: `powerbi-desktop reload --pid <PID>`
Run: `powerbi-desktop screenshot overview-conversion-rate-tooltip --pid <PID>`
Expected: PNG shows the definition + floor-bias caveat sentence.

- [ ] **Step 8: Pause for review**

Show the screenshot to the user. Wait for approval before starting Task 4.

- [ ] **Step 9: Commit**

```bash
git add dashboards/ecommerce_behavior_analytics.SemanticModel/definition/tables/_Measures.tmdl dashboards/ecommerce_behavior_analytics.Report/definition/pages/overview-conversion-rate-tooltip dashboards/ecommerce_behavior_analytics.Report/definition/pages/pages.json dashboards/ecommerce_behavior_analytics.Report/definition/pages/overview/visuals/395ee0f115445cf6890e/visual.json
git commit -m "feat: add Overall Conversion Rate explainability tooltip, repoint from Funnel Floor Bias"
```

---

### Task 4: Total Revenue Tooltip

**Files:**
- Modify: `dashboards/ecommerce_behavior_analytics.SemanticModel/definition/tables/_Measures.tmdl`
- Create: `dashboards/ecommerce_behavior_analytics.Report/definition/pages/overview-total-revenue-tooltip/page.json`
- Create: `dashboards/ecommerce_behavior_analytics.Report/definition/pages/overview-total-revenue-tooltip/visuals/f3d8964db47209939dab/visual.json`
- Modify: `dashboards/ecommerce_behavior_analytics.Report/definition/pages/pages.json`
- Modify: `dashboards/ecommerce_behavior_analytics.Report/definition/pages/overview/visuals/5e3940f7090fb9c90bbf/visual.json`

**Interfaces:**
- Consumes: `DataDictionary_Measures[Description]`/`[Name]`, `[Champion Revenue Share]`.
- Produces: measure `'Total Revenue Tooltip'`; page `overview-total-revenue-tooltip`.

- [ ] **Step 1: Add the `Total Revenue Tooltip` measure**

Append to `_Measures.tmdl`:

```
	/// Explainability tooltip for the Total Revenue KPI card - definition pulled live from the Data Dictionary, paired with the Champion segment's share of it. Bind to an HTML Content visual on the 'overview-total-revenue-tooltip' page.
	measure 'Total Revenue Tooltip' =
			VAR Def = LOOKUPVALUE(DataDictionary_Measures[Description], DataDictionary_Measures[Name], "Total Revenue")
			VAR ChampShare = FORMAT([Champion Revenue Share], "0.0%")
			RETURN
			    "<div style='font-family:""Segoe UI Light"",""Segoe UI"",sans-serif;font-weight:300;color:#FFFFFF;font-size:13px;text-align:justify;'>" &
			        "<p style='margin:0;'>" & Def & "</p>" &
			        "<p style='margin:8px 0 0 0;'>Champion segment customers alone account for " & ChampShare & " of this total, despite being a small fraction of the user base.</p>" &
			    "</div>"
		displayFolder: Tooltips\Overview
		lineageTag: f1537f7f-c842-4e0f-bbb0-46467eed3548

```

- [ ] **Step 2: Create the tooltip page**

Create `dashboards/ecommerce_behavior_analytics.Report/definition/pages/overview-total-revenue-tooltip/page.json`:

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/item/report/definition/page/2.1.0/schema.json",
  "name": "overview-total-revenue-tooltip",
  "displayName": "Total Revenue",
  "displayOption": "FitToPage",
  "height": 300,
  "width": 400,
  "visibility": "HiddenInViewMode",
  "type": "Tooltip"
}
```

- [ ] **Step 3: Create the tooltip's HTML Content visual**

Create `dashboards/ecommerce_behavior_analytics.Report/definition/pages/overview-total-revenue-tooltip/visuals/f3d8964db47209939dab/visual.json`:

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/item/report/definition/visualContainer/2.10.0/schema.json",
  "name": "f3d8964db47209939dab",
  "position": {
    "x": 18.717948717948719,
    "y": 26.666666666666668,
    "z": 0,
    "height": 263.84615384615387,
    "width": 362.5641025641026,
    "tabOrder": 0
  },
  "visual": {
    "visualType": "htmlContent443BE3AD55E043BF878BED274D3A6855",
    "query": {
      "queryState": {
        "content": {
          "projections": [
            {
              "field": {
                "Measure": {
                  "Expression": {
                    "SourceRef": {
                      "Entity": "_Measures"
                    }
                  },
                  "Property": "Total Revenue Tooltip"
                }
              },
              "queryRef": "_Measures.Total Revenue Tooltip",
              "nativeQueryRef": "Total Revenue Tooltip"
            }
          ]
        }
      }
    },
    "drillFilterOtherVisuals": true
  }
}
```

- [ ] **Step 4: Register the new page**

Add `"overview-total-revenue-tooltip"` to the end of `pageOrder` in `pages.json`.

- [ ] **Step 5: Wire the Total Revenue card to the new tooltip**

In `dashboards/ecommerce_behavior_analytics.Report/definition/pages/overview/visuals/5e3940f7090fb9c90bbf/visual.json`, add a `visualTooltip` key inside the existing `visualContainerObjects` object:

```json
      "visualTooltip": [
        {
          "properties": {
            "show": {
              "expr": {
                "Literal": {
                  "Value": "true"
                }
              }
            },
            "section": {
              "expr": {
                "Literal": {
                  "Value": "'overview-total-revenue-tooltip'"
                }
              }
            }
          }
        }
      ],
```

- [ ] **Step 6: Validate**

Run: `powerbi-report-author validate --format text "dashboards/ecommerce_behavior_analytics.Report"`
Expected: 4 errors, 23 warnings — unchanged.

- [ ] **Step 7: Reload and screenshot**

Run: `powerbi-desktop status` — read the current `pid`.
Run: `powerbi-desktop reload --pid <PID>`
Run: `powerbi-desktop screenshot overview-total-revenue-tooltip --pid <PID>`
Expected: PNG shows the definition + Champion-share sentence.

- [ ] **Step 8: Pause for review**

Show the screenshot to the user. Wait for approval before starting Task 5.

- [ ] **Step 9: Commit**

```bash
git add dashboards/ecommerce_behavior_analytics.SemanticModel/definition/tables/_Measures.tmdl dashboards/ecommerce_behavior_analytics.Report/definition/pages/overview-total-revenue-tooltip dashboards/ecommerce_behavior_analytics.Report/definition/pages/pages.json dashboards/ecommerce_behavior_analytics.Report/definition/pages/overview/visuals/5e3940f7090fb9c90bbf/visual.json
git commit -m "feat: add Total Revenue explainability tooltip"
```

---

### Task 5: Cart Abandonment Rate Tooltip

**Files:**
- Modify: `dashboards/ecommerce_behavior_analytics.SemanticModel/definition/tables/_Measures.tmdl`
- Create: `dashboards/ecommerce_behavior_analytics.Report/definition/pages/overview-cart-abandonment-tooltip/page.json`
- Create: `dashboards/ecommerce_behavior_analytics.Report/definition/pages/overview-cart-abandonment-tooltip/visuals/2d0b27eb9d4bd65bb30f/visual.json`
- Modify: `dashboards/ecommerce_behavior_analytics.Report/definition/pages/pages.json`
- Modify: `dashboards/ecommerce_behavior_analytics.Report/definition/pages/overview/visuals/1a65528f1e304c7437cd/visual.json`

**Interfaces:**
- Consumes: `DataDictionary_Measures[Description]`/`[Name]`, `[Overall Conversion Rate]`.
- Produces: measure `'Cart Abandonment Rate Tooltip'`; page `overview-cart-abandonment-tooltip`.

- [ ] **Step 1: Add the `Cart Abandonment Rate Tooltip` measure**

Append to `_Measures.tmdl`:

```
	/// Explainability tooltip for the Cart Abandonment Rate KPI card - definition pulled live from the Data Dictionary, contrasted with the overall conversion rate. Bind to an HTML Content visual on the 'overview-cart-abandonment-tooltip' page.
	measure 'Cart Abandonment Rate Tooltip' =
			VAR Def = LOOKUPVALUE(DataDictionary_Measures[Description], DataDictionary_Measures[Name], "Cart Abandonment Rate")
			VAR ConvRate = FORMAT([Overall Conversion Rate], "0.0%")
			RETURN
			    "<div style='font-family:""Segoe UI Light"",""Segoe UI"",sans-serif;font-weight:300;color:#FFFFFF;font-size:13px;text-align:justify;'>" &
			        "<p style='margin:0;'>" & Def & "</p>" &
			        "<p style='margin:8px 0 0 0;'>Elsewhere on this page, " & ConvRate & " of all views convert - most cart-adds still don't finish, even among visitors who got this far.</p>" &
			    "</div>"
		displayFolder: Tooltips\Overview
		lineageTag: d483ffea-e9e7-48aa-8246-53d2e5360f33

```

- [ ] **Step 2: Create the tooltip page**

Create `dashboards/ecommerce_behavior_analytics.Report/definition/pages/overview-cart-abandonment-tooltip/page.json`:

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/item/report/definition/page/2.1.0/schema.json",
  "name": "overview-cart-abandonment-tooltip",
  "displayName": "Cart Abandonment Rate",
  "displayOption": "FitToPage",
  "height": 300,
  "width": 400,
  "visibility": "HiddenInViewMode",
  "type": "Tooltip"
}
```

- [ ] **Step 3: Create the tooltip's HTML Content visual**

Create `dashboards/ecommerce_behavior_analytics.Report/definition/pages/overview-cart-abandonment-tooltip/visuals/2d0b27eb9d4bd65bb30f/visual.json`:

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/item/report/definition/visualContainer/2.10.0/schema.json",
  "name": "2d0b27eb9d4bd65bb30f",
  "position": {
    "x": 18.717948717948719,
    "y": 26.666666666666668,
    "z": 0,
    "height": 263.84615384615387,
    "width": 362.5641025641026,
    "tabOrder": 0
  },
  "visual": {
    "visualType": "htmlContent443BE3AD55E043BF878BED274D3A6855",
    "query": {
      "queryState": {
        "content": {
          "projections": [
            {
              "field": {
                "Measure": {
                  "Expression": {
                    "SourceRef": {
                      "Entity": "_Measures"
                    }
                  },
                  "Property": "Cart Abandonment Rate Tooltip"
                }
              },
              "queryRef": "_Measures.Cart Abandonment Rate Tooltip",
              "nativeQueryRef": "Cart Abandonment Rate Tooltip"
            }
          ]
        }
      }
    },
    "drillFilterOtherVisuals": true
  }
}
```

- [ ] **Step 4: Register the new page**

Add `"overview-cart-abandonment-tooltip"` to the end of `pageOrder` in `pages.json`.

- [ ] **Step 5: Wire the Cart Abandonment Rate card to the new tooltip**

In `dashboards/ecommerce_behavior_analytics.Report/definition/pages/overview/visuals/1a65528f1e304c7437cd/visual.json`, add a `visualTooltip` key inside the existing `visualContainerObjects` object:

```json
      "visualTooltip": [
        {
          "properties": {
            "show": {
              "expr": {
                "Literal": {
                  "Value": "true"
                }
              }
            },
            "section": {
              "expr": {
                "Literal": {
                  "Value": "'overview-cart-abandonment-tooltip'"
                }
              }
            }
          }
        }
      ],
```

- [ ] **Step 6: Validate**

Run: `powerbi-report-author validate --format text "dashboards/ecommerce_behavior_analytics.Report"`
Expected: 4 errors, 23 warnings — unchanged.

- [ ] **Step 7: Reload and screenshot**

Run: `powerbi-desktop status` — read the current `pid`.
Run: `powerbi-desktop reload --pid <PID>`
Run: `powerbi-desktop screenshot overview-cart-abandonment-tooltip --pid <PID>`
Expected: PNG shows the definition + contrast sentence.

- [ ] **Step 8: Pause for review**

Show the screenshot to the user. Wait for approval before starting Task 6.

- [ ] **Step 9: Commit**

```bash
git add dashboards/ecommerce_behavior_analytics.SemanticModel/definition/tables/_Measures.tmdl dashboards/ecommerce_behavior_analytics.Report/definition/pages/overview-cart-abandonment-tooltip dashboards/ecommerce_behavior_analytics.Report/definition/pages/pages.json dashboards/ecommerce_behavior_analytics.Report/definition/pages/overview/visuals/1a65528f1e304c7437cd/visual.json
git commit -m "feat: add Cart Abandonment Rate explainability tooltip"
```

---

### Task 6: Champion Revenue Share Tooltip

**Files:**
- Modify: `dashboards/ecommerce_behavior_analytics.SemanticModel/definition/tables/_Measures.tmdl`
- Create: `dashboards/ecommerce_behavior_analytics.Report/definition/pages/overview-champion-revenue-tooltip/page.json`
- Create: `dashboards/ecommerce_behavior_analytics.Report/definition/pages/overview-champion-revenue-tooltip/visuals/81f1ffff539536a4679f/visual.json`
- Modify: `dashboards/ecommerce_behavior_analytics.Report/definition/pages/pages.json`
- Modify: `dashboards/ecommerce_behavior_analytics.Report/definition/pages/overview/visuals/a942e29e66934f0e44ea/visual.json`

**Interfaces:**
- Consumes: `DataDictionary_Measures[Description]`/`[Name]`, `[Champion Revenue Share]`, `FactRFMSegment[PctUsers]`, `FactRFMSegment[Segment]`.
- Produces: measure `'Champion Revenue Share Tooltip'`; page `overview-champion-revenue-tooltip`.

- [ ] **Step 1: Add the `Champion Revenue Share Tooltip` measure**

Append to `_Measures.tmdl`:

```
	/// Explainability tooltip for the Champion Revenue Share KPI card - definition pulled live from the Data Dictionary, paired with a live-computed concentration multiple (revenue share vs. user share) for the Champion segment specifically. Bind to an HTML Content visual on the 'overview-champion-revenue-tooltip' page.
	measure 'Champion Revenue Share Tooltip' =
			VAR Def = LOOKUPVALUE(DataDictionary_Measures[Description], DataDictionary_Measures[Name], "Champion Revenue Share")
			VAR ChampUserShare = CALCULATE(SUM(FactRFMSegment[PctUsers]), FactRFMSegment[Segment] = "Champion")
			VAR Multiple = FORMAT(DIVIDE([Champion Revenue Share], ChampUserShare), "0.0")
			VAR UserSharePct = FORMAT(ChampUserShare, "0%")
			RETURN
			    "<div style='font-family:""Segoe UI Light"",""Segoe UI"",sans-serif;font-weight:300;color:#FFFFFF;font-size:13px;text-align:justify;'>" &
			        "<p style='margin:0;'>" & Def & "</p>" &
			        "<p style='margin:8px 0 0 0;'>Champions make up just " & UserSharePct & " of the customer base but generate this share of revenue - " & Multiple & "x their proportional share.</p>" &
			    "</div>"
		displayFolder: Tooltips\Overview
		lineageTag: 0f20a30b-d035-411b-ac00-7f426338ea5d

```

- [ ] **Step 2: Create the tooltip page**

Create `dashboards/ecommerce_behavior_analytics.Report/definition/pages/overview-champion-revenue-tooltip/page.json`:

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/item/report/definition/page/2.1.0/schema.json",
  "name": "overview-champion-revenue-tooltip",
  "displayName": "Champion Revenue Share",
  "displayOption": "FitToPage",
  "height": 300,
  "width": 400,
  "visibility": "HiddenInViewMode",
  "type": "Tooltip"
}
```

- [ ] **Step 3: Create the tooltip's HTML Content visual**

Create `dashboards/ecommerce_behavior_analytics.Report/definition/pages/overview-champion-revenue-tooltip/visuals/81f1ffff539536a4679f/visual.json`:

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/item/report/definition/visualContainer/2.10.0/schema.json",
  "name": "81f1ffff539536a4679f",
  "position": {
    "x": 18.717948717948719,
    "y": 26.666666666666668,
    "z": 0,
    "height": 263.84615384615387,
    "width": 362.5641025641026,
    "tabOrder": 0
  },
  "visual": {
    "visualType": "htmlContent443BE3AD55E043BF878BED274D3A6855",
    "query": {
      "queryState": {
        "content": {
          "projections": [
            {
              "field": {
                "Measure": {
                  "Expression": {
                    "SourceRef": {
                      "Entity": "_Measures"
                    }
                  },
                  "Property": "Champion Revenue Share Tooltip"
                }
              },
              "queryRef": "_Measures.Champion Revenue Share Tooltip",
              "nativeQueryRef": "Champion Revenue Share Tooltip"
            }
          ]
        }
      }
    },
    "drillFilterOtherVisuals": true
  }
}
```

- [ ] **Step 4: Register the new page**

Add `"overview-champion-revenue-tooltip"` to the end of `pageOrder` in `pages.json`.

- [ ] **Step 5: Wire the Champion Revenue Share card to the new tooltip**

In `dashboards/ecommerce_behavior_analytics.Report/definition/pages/overview/visuals/a942e29e66934f0e44ea/visual.json`, add a `visualTooltip` key inside the existing `visualContainerObjects` object:

```json
      "visualTooltip": [
        {
          "properties": {
            "show": {
              "expr": {
                "Literal": {
                  "Value": "true"
                }
              }
            },
            "section": {
              "expr": {
                "Literal": {
                  "Value": "'overview-champion-revenue-tooltip'"
                }
              }
            }
          }
        }
      ],
```

- [ ] **Step 6: Validate**

Run: `powerbi-report-author validate --format text "dashboards/ecommerce_behavior_analytics.Report"`
Expected: 4 errors, 23 warnings — unchanged.

- [ ] **Step 7: Reload and screenshot**

Run: `powerbi-desktop status` — read the current `pid`.
Run: `powerbi-desktop reload --pid <PID>`
Run: `powerbi-desktop screenshot overview-champion-revenue-tooltip --pid <PID>`
Expected: PNG shows the definition + concentration-multiple sentence.

- [ ] **Step 8: Pause for review**

Show the screenshot to the user. Wait for approval before starting Task 7.

- [ ] **Step 9: Commit**

```bash
git add dashboards/ecommerce_behavior_analytics.SemanticModel/definition/tables/_Measures.tmdl dashboards/ecommerce_behavior_analytics.Report/definition/pages/overview-champion-revenue-tooltip dashboards/ecommerce_behavior_analytics.Report/definition/pages/pages.json dashboards/ecommerce_behavior_analytics.Report/definition/pages/overview/visuals/a942e29e66934f0e44ea/visual.json
git commit -m "feat: add Champion Revenue Share explainability tooltip"
```

---

### Task 7: COVID Impact on Conversion Tooltip

**Files:**
- Modify: `dashboards/ecommerce_behavior_analytics.SemanticModel/definition/tables/_Measures.tmdl`
- Create: `dashboards/ecommerce_behavior_analytics.Report/definition/pages/overview-covid-impact-tooltip/page.json`
- Create: `dashboards/ecommerce_behavior_analytics.Report/definition/pages/overview-covid-impact-tooltip/visuals/98c228377f220e43434b/visual.json`
- Modify: `dashboards/ecommerce_behavior_analytics.Report/definition/pages/pages.json`
- Modify: `dashboards/ecommerce_behavior_analytics.Report/definition/pages/overview/visuals/0dd2fc0d85d7eb225638/visual.json`

**Interfaces:**
- Consumes: `DataDictionary_Measures[Description]`/`[Name]` (looked up by the underlying measure name `COVID Session Conversion Lift`, not the card's display title).
- Produces: measure `'COVID Impact on Conversion Tooltip'`; page `overview-covid-impact-tooltip`.

**Note:** this card is bound to the `[COVID Session Conversion Lift]` measure but its display title is "COVID Impact on Conversion" — the `LOOKUPVALUE` in Step 1 must use the underlying measure name (`"COVID Session Conversion Lift"`), matching what's actually in `DataDictionary_Measures[Name]`.

- [ ] **Step 1: Add the `COVID Impact on Conversion Tooltip` measure**

Append to `_Measures.tmdl`:

```
	/// Explainability tooltip for the COVID Impact on Conversion KPI card - definition pulled live from the Data Dictionary for the underlying COVID Session Conversion Lift measure, plus the Logging Gap data quality tie-in since it directly affects the pre-COVID baseline this measure compares against. Bind to an HTML Content visual on the 'overview-covid-impact-tooltip' page.
	measure 'COVID Impact on Conversion Tooltip' =
			VAR Def = LOOKUPVALUE(DataDictionary_Measures[Description], DataDictionary_Measures[Name], "COVID Session Conversion Lift")
			RETURN
			    "<div style='font-family:""Segoe UI Light"",""Segoe UI"",sans-serif;font-weight:300;color:#FFFFFF;font-size:13px;text-align:justify;'>" &
			        "<p style='margin:0;'>" & Def & "</p>" &
			        "<p style='margin:8px 0 0 0;'>Note: Feb 27, 2020 is excluded from the pre-COVID baseline used here due to a platform logging outage that dropped roughly 90% of that day's events - see Data Quality Notes for detail.</p>" &
			    "</div>"
		displayFolder: Tooltips\Overview
		lineageTag: 3501e3ce-7389-42f7-9b1b-0497b0c2e5bd

```

- [ ] **Step 2: Create the tooltip page**

Create `dashboards/ecommerce_behavior_analytics.Report/definition/pages/overview-covid-impact-tooltip/page.json`:

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/item/report/definition/page/2.1.0/schema.json",
  "name": "overview-covid-impact-tooltip",
  "displayName": "COVID Impact on Conversion",
  "displayOption": "FitToPage",
  "height": 300,
  "width": 400,
  "visibility": "HiddenInViewMode",
  "type": "Tooltip"
}
```

- [ ] **Step 3: Create the tooltip's HTML Content visual**

Create `dashboards/ecommerce_behavior_analytics.Report/definition/pages/overview-covid-impact-tooltip/visuals/98c228377f220e43434b/visual.json`:

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/item/report/definition/visualContainer/2.10.0/schema.json",
  "name": "98c228377f220e43434b",
  "position": {
    "x": 18.717948717948719,
    "y": 26.666666666666668,
    "z": 0,
    "height": 263.84615384615387,
    "width": 362.5641025641026,
    "tabOrder": 0
  },
  "visual": {
    "visualType": "htmlContent443BE3AD55E043BF878BED274D3A6855",
    "query": {
      "queryState": {
        "content": {
          "projections": [
            {
              "field": {
                "Measure": {
                  "Expression": {
                    "SourceRef": {
                      "Entity": "_Measures"
                    }
                  },
                  "Property": "COVID Impact on Conversion Tooltip"
                }
              },
              "queryRef": "_Measures.COVID Impact on Conversion Tooltip",
              "nativeQueryRef": "COVID Impact on Conversion Tooltip"
            }
          ]
        }
      }
    },
    "drillFilterOtherVisuals": true
  }
}
```

- [ ] **Step 4: Register the new page**

Add `"overview-covid-impact-tooltip"` to the end of `pageOrder` in `pages.json`.

- [ ] **Step 5: Repoint the COVID card's tooltip from Default to the new page**

In `dashboards/ecommerce_behavior_analytics.Report/definition/pages/overview/visuals/0dd2fc0d85d7eb225638/visual.json`, the existing `visualContainerObjects.visualTooltip` block reads:

```json
      "visualTooltip": [
        {
          "properties": {
            "show": {
              "expr": {
                "Literal": {
                  "Value": "true"
                }
              }
            },
            "type": {
              "expr": {
                "Literal": {
                  "Value": "'Default'"
                }
              }
            }
          }
        }
      ]
```

Replace the `"type"` property entirely with a `"section"` property so it points at the new custom tooltip page:

```json
      "visualTooltip": [
        {
          "properties": {
            "show": {
              "expr": {
                "Literal": {
                  "Value": "true"
                }
              }
            },
            "section": {
              "expr": {
                "Literal": {
                  "Value": "'overview-covid-impact-tooltip'"
                }
              }
            }
          }
        }
      ]
```

- [ ] **Step 6: Validate**

Run: `powerbi-report-author validate --format text "dashboards/ecommerce_behavior_analytics.Report"`
Expected: 4 errors, 23 warnings — unchanged.

- [ ] **Step 7: Reload and screenshot**

Run: `powerbi-desktop status` — read the current `pid`.
Run: `powerbi-desktop reload --pid <PID>`
Run: `powerbi-desktop screenshot overview-covid-impact-tooltip --pid <PID>`
Expected: PNG shows the definition + logging-gap sentence.

- [ ] **Step 8: Pause for review**

Show the screenshot to the user. Wait for approval before starting Task 8.

- [ ] **Step 9: Commit**

```bash
git add dashboards/ecommerce_behavior_analytics.SemanticModel/definition/tables/_Measures.tmdl dashboards/ecommerce_behavior_analytics.Report/definition/pages/overview-covid-impact-tooltip dashboards/ecommerce_behavior_analytics.Report/definition/pages/pages.json dashboards/ecommerce_behavior_analytics.Report/definition/pages/overview/visuals/0dd2fc0d85d7eb225638/visual.json
git commit -m "feat: add COVID Impact on Conversion explainability tooltip"
```

---

### Task 8: Month-1 Retention Avg Tooltip

**Files:**
- Modify: `dashboards/ecommerce_behavior_analytics.SemanticModel/definition/tables/_Measures.tmdl`
- Create: `dashboards/ecommerce_behavior_analytics.Report/definition/pages/overview-retention-tooltip/page.json`
- Create: `dashboards/ecommerce_behavior_analytics.Report/definition/pages/overview-retention-tooltip/visuals/79d18f07f892f0c3b95e/visual.json`
- Modify: `dashboards/ecommerce_behavior_analytics.Report/definition/pages/pages.json`
- Modify: `dashboards/ecommerce_behavior_analytics.Report/definition/pages/overview/visuals/bb50541a1398fe512190/visual.json`

**Interfaces:**
- Consumes: `DataDictionary_Measures[Description]`/`[Name]` (looked up by `"Month-1 Retention Avg"`, the underlying measure — this card is bound to the compound `'Month-1 Retention KPI Card'` HTML measure, not directly to `Month-1 Retention Avg`, but the Data Dictionary description exists under the latter name).
- Produces: measure `'Month-1 Retention Avg Tooltip'`; page `overview-retention-tooltip`.

**Note:** this card's own HTML already shows a "toward the lower/higher/middle of the historical cohort range" badge (fed by `Retention Position Text`). The tooltip below deliberately does **not** repeat that framing — it explains cohort timing instead, satisfying the no-overlap rule.

- [ ] **Step 1: Add the `Month-1 Retention Avg Tooltip` measure**

Append to `_Measures.tmdl`:

```
	/// Explainability tooltip for the Month-1 Retention Avg KPI card - definition pulled live from the Data Dictionary, plus a cohort-timing clarification. Deliberately does not repeat the historical-position badge text already shown on this card's own HTML content. Bind to an HTML Content visual on the 'overview-retention-tooltip' page.
	measure 'Month-1 Retention Avg Tooltip' =
			VAR Def = LOOKUPVALUE(DataDictionary_Measures[Description], DataDictionary_Measures[Name], "Month-1 Retention Avg")
			RETURN
			    "<div style='font-family:""Segoe UI Light"",""Segoe UI"",sans-serif;font-weight:300;color:#FFFFFF;font-size:13px;text-align:justify;'>" &
			        "<p style='margin:0;'>" & Def & "</p>" &
			        "<p style='margin:8px 0 0 0;'>Each acquisition cohort is grouped by the calendar month of a customer's first purchase; M1 checks whether they returned to purchase again in their second calendar month on record.</p>" &
			    "</div>"
		displayFolder: Tooltips\Overview
		lineageTag: a8f0783d-f5fb-470d-a048-b701715c1e26

```

- [ ] **Step 2: Create the tooltip page**

Create `dashboards/ecommerce_behavior_analytics.Report/definition/pages/overview-retention-tooltip/page.json`:

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/item/report/definition/page/2.1.0/schema.json",
  "name": "overview-retention-tooltip",
  "displayName": "Month-1 Retention Avg",
  "displayOption": "FitToPage",
  "height": 300,
  "width": 400,
  "visibility": "HiddenInViewMode",
  "type": "Tooltip"
}
```

- [ ] **Step 3: Create the tooltip's HTML Content visual**

Create `dashboards/ecommerce_behavior_analytics.Report/definition/pages/overview-retention-tooltip/visuals/79d18f07f892f0c3b95e/visual.json`:

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/item/report/definition/visualContainer/2.10.0/schema.json",
  "name": "79d18f07f892f0c3b95e",
  "position": {
    "x": 18.717948717948719,
    "y": 26.666666666666668,
    "z": 0,
    "height": 263.84615384615387,
    "width": 362.5641025641026,
    "tabOrder": 0
  },
  "visual": {
    "visualType": "htmlContent443BE3AD55E043BF878BED274D3A6855",
    "query": {
      "queryState": {
        "content": {
          "projections": [
            {
              "field": {
                "Measure": {
                  "Expression": {
                    "SourceRef": {
                      "Entity": "_Measures"
                    }
                  },
                  "Property": "Month-1 Retention Avg Tooltip"
                }
              },
              "queryRef": "_Measures.Month-1 Retention Avg Tooltip",
              "nativeQueryRef": "Month-1 Retention Avg Tooltip"
            }
          ]
        }
      }
    },
    "drillFilterOtherVisuals": true
  }
}
```

- [ ] **Step 4: Register the new page**

Add `"overview-retention-tooltip"` to the end of `pageOrder` in `pages.json`.

- [ ] **Step 5: Wire the Month-1 Retention card to the new tooltip**

In `dashboards/ecommerce_behavior_analytics.Report/definition/pages/overview/visuals/bb50541a1398fe512190/visual.json`, the `visualContainerObjects` object currently has only a `background` key. Add a `visualTooltip` key alongside it:

```json
      "visualTooltip": [
        {
          "properties": {
            "show": {
              "expr": {
                "Literal": {
                  "Value": "true"
                }
              }
            },
            "section": {
              "expr": {
                "Literal": {
                  "Value": "'overview-retention-tooltip'"
                }
              }
            }
          }
        }
      ],
```

- [ ] **Step 6: Validate**

Run: `powerbi-report-author validate --format text "dashboards/ecommerce_behavior_analytics.Report"`
Expected: 4 errors, 23 warnings — unchanged.

- [ ] **Step 7: Reload and screenshot**

Run: `powerbi-desktop status` — read the current `pid`.
Run: `powerbi-desktop reload --pid <PID>`
Run: `powerbi-desktop screenshot overview-retention-tooltip --pid <PID>`
Expected: PNG shows the definition + cohort-timing sentence.

- [ ] **Step 8: Pause for review**

Show the screenshot to the user. This is the last card on Overview — after approval, the page is done and the same pattern moves to the next report page (chart-type tooltips there will use the native Tooltip-field-well + Sentence-format mechanism instead, per the design spec).

- [ ] **Step 9: Commit**

```bash
git add dashboards/ecommerce_behavior_analytics.SemanticModel/definition/tables/_Measures.tmdl dashboards/ecommerce_behavior_analytics.Report/definition/pages/overview-retention-tooltip dashboards/ecommerce_behavior_analytics.Report/definition/pages/pages.json dashboards/ecommerce_behavior_analytics.Report/definition/pages/overview/visuals/bb50541a1398fe512190/visual.json
git commit -m "feat: add Month-1 Retention Avg explainability tooltip"
```
