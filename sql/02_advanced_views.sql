-- ============================================================================
-- ADVANCED ANALYTICAL VIEWS FOR LOOKER STUDIO
-- These views pre-compute the advanced insights so Looker can render them
-- Run these AFTER the base unified model is created
-- ============================================================================


-- VIEW: Campaign Efficient Frontier with Quadrant Classification
-- Supports Finding #2 — gives Looker a "quadrant" column to color-code
CREATE OR REPLACE VIEW `marketing_analytics.v_campaign_quadrant` AS
WITH campaign_stats AS (
    SELECT
        platform,
        campaign_id,
        campaign_name,
        SUM(spend)                                  AS spend,
        SUM(conversions)                            AS conversions,
        SUM(clicks)                                 AS clicks,
        SUM(impressions)                            AS impressions,
        SAFE_DIVIDE(SUM(spend), SUM(conversions))   AS cpa,
        SAFE_DIVIDE(SUM(conversions), SUM(clicks))  AS cvr,
        SAFE_DIVIDE(SUM(clicks), SUM(impressions))  AS ctr,
        COUNT(DISTINCT date)                        AS active_days
    FROM `marketing_analytics.unified_ad_performance`
    GROUP BY platform, campaign_id, campaign_name
),
medians AS (
    SELECT
        PERCENTILE_CONT(cpa, 0.5) OVER() AS median_cpa,
        PERCENTILE_CONT(cvr, 0.5) OVER() AS median_cvr
    FROM campaign_stats
    LIMIT 1
)
SELECT
    c.*,
    CASE
        WHEN c.cpa <= m.median_cpa AND c.cvr >= m.median_cvr THEN 'Scale'
        WHEN c.cpa <= m.median_cpa AND c.cvr <  m.median_cvr THEN 'Optimize Funnel'
        WHEN c.cpa >  m.median_cpa AND c.cvr >= m.median_cvr THEN 'Reduce Cost'
        ELSE 'Fix or Kill'
    END AS quadrant,
    m.median_cpa,
    m.median_cvr
FROM campaign_stats c
CROSS JOIN medians m;


-- VIEW: Day-of-Week Performance
-- Supports Finding #11
CREATE OR REPLACE VIEW `marketing_analytics.v_day_of_week` AS
SELECT
    FORMAT_DATE('%A', date)                             AS day_name,
    EXTRACT(DAYOFWEEK FROM date)                        AS day_num,
    SUM(spend)                                          AS total_spend,
    SUM(conversions)                                    AS total_conversions,
    SUM(clicks)                                         AS total_clicks,
    SUM(impressions)                                    AS total_impressions,
    SAFE_DIVIDE(SUM(spend), SUM(conversions))           AS cpa,
    SAFE_DIVIDE(SUM(conversions), SUM(clicks))          AS cvr,
    SAFE_DIVIDE(SUM(clicks), SUM(impressions))          AS ctr,
    COUNT(DISTINCT date)                                AS num_days
FROM `marketing_analytics.unified_ad_performance`
GROUP BY day_name, day_num;


-- VIEW: Weekly Momentum with WoW Change
-- Supports Finding #10
CREATE OR REPLACE VIEW `marketing_analytics.v_weekly_momentum` AS
WITH weekly AS (
    SELECT
        DATE_TRUNC(date, ISOWEEK)                       AS week_start,
        EXTRACT(ISOWEEK FROM date)                      AS week_num,
        SUM(spend)                                      AS spend,
        SUM(conversions)                                AS conversions,
        SUM(clicks)                                     AS clicks,
        SUM(impressions)                                AS impressions,
        SAFE_DIVIDE(SUM(spend), SUM(conversions))       AS cpa,
        SAFE_DIVIDE(SUM(clicks), SUM(impressions))      AS ctr
    FROM `marketing_analytics.unified_ad_performance`
    GROUP BY week_start, week_num
)
SELECT
    w.*,
    LAG(w.conversions) OVER (ORDER BY w.week_start)     AS prev_week_conv,
    SAFE_DIVIDE(
        w.conversions - LAG(w.conversions) OVER (ORDER BY w.week_start),
        LAG(w.conversions) OVER (ORDER BY w.week_start)
    ) AS wow_conv_change,
    SAFE_DIVIDE(
        w.spend - LAG(w.spend) OVER (ORDER BY w.week_start),
        LAG(w.spend) OVER (ORDER BY w.week_start)
    ) AS wow_spend_change
FROM weekly w;


-- VIEW: Google Quality Score Impact
-- Supports Finding #4
CREATE OR REPLACE VIEW `marketing_analytics.v_google_quality_score` AS
SELECT
    quality_score,
    COUNT(*)                                            AS observations,
    SUM(spend)                                          AS total_spend,
    SUM(conversions)                                    AS total_conversions,
    SUM(clicks)                                         AS total_clicks,
    SAFE_DIVIDE(SUM(spend), SUM(conversions))           AS cpa,
    SAFE_DIVIDE(SUM(spend), SUM(clicks))                AS avg_cpc,
    SAFE_DIVIDE(SUM(clicks), SUM(impressions))          AS ctr
FROM `marketing_analytics.unified_ad_performance`
WHERE platform = 'google'
GROUP BY quality_score
ORDER BY quality_score;


-- VIEW: TikTok Video Funnel by Campaign
-- Supports Finding #7
CREATE OR REPLACE VIEW `marketing_analytics.v_tiktok_video_funnel` AS
SELECT
    campaign_name,
    SUM(video_views)                                                AS total_views,
    SUM(video_watch_25)                                             AS watch_25,
    SUM(video_watch_50)                                             AS watch_50,
    SUM(video_watch_75)                                             AS watch_75,
    SUM(video_watch_100)                                            AS watch_100,
    SAFE_DIVIDE(SUM(video_watch_25),  SUM(video_views))             AS rate_25,
    SAFE_DIVIDE(SUM(video_watch_50),  SUM(video_views))             AS rate_50,
    SAFE_DIVIDE(SUM(video_watch_75),  SUM(video_views))             AS rate_75,
    SAFE_DIVIDE(SUM(video_watch_100), SUM(video_views))             AS rate_100,
    SUM(conversions)                                                AS conversions,
    SAFE_DIVIDE(SUM(conversions), SUM(video_views))                 AS conv_per_view,
    SAFE_DIVIDE(SUM(spend), SUM(conversions))                       AS cpa
FROM `marketing_analytics.unified_ad_performance`
WHERE platform = 'tiktok'
GROUP BY campaign_name;


-- VIEW: Spend-Conversion Allocation Gap
-- Supports Finding #1 — pre-computes the gap for KPI cards
CREATE OR REPLACE VIEW `marketing_analytics.v_allocation_gap` AS
WITH totals AS (
    SELECT
        SUM(spend)       AS grand_spend,
        SUM(conversions) AS grand_conv,
        SUM(clicks)      AS grand_clicks
    FROM `marketing_analytics.unified_ad_performance`
)
SELECT
    u.platform,
    SUM(u.spend)                                    AS spend,
    SUM(u.conversions)                              AS conversions,
    SUM(u.clicks)                                   AS clicks,
    SAFE_DIVIDE(SUM(u.spend), t.grand_spend)        AS spend_share,
    SAFE_DIVIDE(SUM(u.conversions), t.grand_conv)   AS conv_share,
    SAFE_DIVIDE(SUM(u.clicks), t.grand_clicks)      AS click_share,
    -- The gap: positive = over-delivering, negative = under-delivering
    SAFE_DIVIDE(SUM(u.conversions), t.grand_conv)
      - SAFE_DIVIDE(SUM(u.spend), t.grand_spend)   AS conv_spend_gap_pp
FROM `marketing_analytics.unified_ad_performance` u
CROSS JOIN totals t
GROUP BY u.platform, t.grand_spend, t.grand_conv, t.grand_clicks;


-- VIEW: Cross-Channel Halo (pre-computed daily pairs for text insight)
-- Supports Finding #3 — compute in SQL, display as scorecard/text in Looker
CREATE OR REPLACE VIEW `marketing_analytics.v_halo_daily` AS
WITH tiktok_daily AS (
    SELECT date, SUM(spend) AS tt_spend
    FROM `marketing_analytics.unified_ad_performance`
    WHERE platform = 'tiktok'
    GROUP BY date
),
google_brand_daily AS (
    SELECT date, SUM(conversions) AS g_brand_conv
    FROM `marketing_analytics.unified_ad_performance`
    WHERE platform = 'google' AND campaign_name = 'Search_Brand_Terms'
    GROUP BY date
)
SELECT
    t.date,
    t.tt_spend,
    g.g_brand_conv
FROM tiktok_daily t
JOIN google_brand_daily g ON t.date = g.date
ORDER BY t.date;
-- Note: Looker Studio cannot compute correlation natively.
-- Use this view to create a scatter chart (tt_spend on X, g_brand_conv on Y)
-- which visually shows the relationship. State the r-value in a text annotation.
