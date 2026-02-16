# Cross-Channel Marketing Analytics — Improvado Assessment

> **Senior Marketing Data Analyst** — Technical Assignment Submission  
> **Author:** Michael Ikechukwu Udeh  
> **Date:** February 2026

## The Challenge

Unify raw advertising data from Facebook Ads, Google Ads, and TikTok into a single data model, load it into a cloud database, and build a dashboard that surfaces actionable cross-channel insights.

## Live Dashboards

| Dashboard | Link | Description |
|-----------|------|-------------|
| **Cross-Channel Performance** | [→ Open Dashboard](dashboard/index.html) | One-page interactive dashboard with KPI cards, allocation analysis, trends, campaign table, and efficiency matrix |
| **Advanced Insight Report** | [→ Open Report](dashboard/advanced-insights.html) | 12 analytical dimensions including cross-channel halo effect, spend elasticity, quality score leverage, and budget reallocation simulation |

> **Note:** After deploying to GitHub Pages, replace the links above with your `https://yourusername.github.io/repo-name/dashboard/` URLs.

## Repository Structure

```
├── sql/
│   ├── 01_schema_and_unified_model.sql    # Staging DDLs, unified model, validation, base views
│   └── 02_advanced_views.sql              # Advanced analytical views (quadrant, day-of-week, halo, etc.)
│
├── dashboard/
│   ├── index.html                         # Primary interactive dashboard (Chart.js, self-contained)
│   └── advanced-insights.html             # Deep-dive insight report with 12 findings
│
├── data/
│   ├── 01_facebook_ads.csv                # Source: Facebook Ads (110 rows, 13 columns)
│   ├── 02_google_ads.csv                  # Source: Google Ads (110 rows, 14 columns)
│   ├── 03_tiktok_ads.csv                  # Source: TikTok Ads (110 rows, 17 columns)
│   └── unified_ad_performance.csv         # Output: Unified model (330 rows, 29 columns)
│
├── docs/
│   ├── 01_setup_guide.docx               # Step-by-step BigQuery + Looker Studio deployment guide
│   ├── 02_methodology.docx               # Thought process, design decisions, metric glossary
│   └── 03_insight_report.docx            # Executive insight report with recommendations
│
└── README.md
```

## Approach

### Data Model

Two-layer architecture following modern warehouse best practices:

- **Staging Layer** (`stg_` tables): Raw data, schema-matched to each platform's export format. No transformations. Source of truth for auditability.
- **Mart Layer** (`unified_ad_performance`): Harmonized fact table that normalizes naming conventions (`spend`/`cost` → `spend`, `ad_set`/`ad_group`/`adgroup` → `ad_group`), computes derived metrics (CTR, CPC, CPA, CVR) with `SAFE_DIVIDE`, and retains platform-specific metrics as nullable columns.

All derived metrics are recomputed from base metrics in the unified table — not carried from source — ensuring consistency across platforms.

### Key Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Column naming | `ad_group` (Google convention) | Industry standard, most widely understood |
| Spend column | `spend` (not `cost`) | Natural business language ("how much did we spend?") |
| Derived metrics | Recomputed, not carried | Ensures identical calculation logic across all 3 platforms |
| Platform-specific fields | Nullable columns, not dropped | Preserves optionality for platform deep dives without data loss |
| Validation queries | Included in SQL script | Row counts, spend reconciliation, null checks, metric consistency |

### Analytical Dimensions

The analysis goes beyond standard reporting to include 12 dimensions:

1. **Spend-Conversion Gap** — TikTok over-indexed by 6.5 percentage points
2. **Campaign Efficient Frontier** — 4-quadrant classification (Scale / Optimize / Reduce / Fix)
3. **Cross-Channel Halo Effect** — TikTok awareness correlates with Google brand search (r=0.41)
4. **Quality Score → CPA Leverage** — Each +1 QS point reduces Google CPA by ~40%
5. **Spend Elasticity** — No diminishing returns detected; portfolio is under-invested
6. **Impression Share Headroom** — 2,465 estimated conversions left on the table
7. **TikTok Video Funnel** — Influencer content holds attention 37% better than generic
8. **Social Signal Correlation** — Video completion rate (r=0.88) is the strongest conversion predictor
9. **Facebook Frequency Analysis** — No fatigue detected; headroom to increase retargeting
10. **Weekly Momentum** — 52% spend increase with flat CPA over 4 weeks
11. **Day-of-Week Patterns** — Thursday best CPA ($9.46), Sunday worst ($9.90)
12. **Budget Reallocation Simulation** — +270 conversions for $0 additional spend

### Top-Line Results

| Metric | Value |
|--------|-------|
| Total Spend | $130,244.90 |
| Total Conversions | 13,363 |
| Blended CPA | $9.75 |
| Best Campaign CPA | $5.10 (Google Search Brand) |
| Worst Campaign CPA | $24.80 (Google Search Generic) |
| Estimated Improvement from Reallocation | +270 conv (+2.0% CPA improvement) |

## Technology Stack

| Component | Tool | Why |
|-----------|------|-----|
| Cloud Database | Google BigQuery (Sandbox) | Free tier, no credit card, native SQL, Looker Studio integration |
| Dashboard | HTML/CSS/JS + Chart.js | Self-contained, fully interactive, zero dependencies, deployable on GitHub Pages |
| BI Dashboard | Looker Studio | Connected to BigQuery for live data, shareable link |
| Analysis | Python + SQL | Data profiling, correlation analysis, elasticity computation |

## Deployment

### GitHub Pages (HTML Dashboard)

```bash
# In your GitHub repo settings:
# Settings → Pages → Source: Deploy from branch → Branch: main → Folder: / (root)
# Dashboard will be live at: https://yourusername.github.io/repo-name/dashboard/
```

### BigQuery + Looker Studio

See `docs/01_setup_guide.docx` for detailed step-by-step instructions. Summary:

1. Create BigQuery project + `marketing_analytics` dataset
2. Upload the 3 source CSVs as `stg_facebook_ads`, `stg_google_ads`, `stg_tiktok_ads`
3. Run `sql/01_schema_and_unified_model.sql` (skip to STEP 3 for the unified model)
4. Run `sql/02_advanced_views.sql` for analytical views
5. Connect Looker Studio to BigQuery → Build dashboard from views

---

*Built as part of the Improvado Senior Marketing Data Analyst technical assessment.*
