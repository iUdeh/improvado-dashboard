-- IMPROVADO SENIOR MARKETING ANALYST — TECHNICAL ASSESSMENT
-- SQL Script: Schema Definition, Data Transformation & Unified Model
-- Author: Michael Ikechukwu Udeh
-- Date: 2026-02-16
-- Database: Google BigQuery


-- STEP 1: SOURCE TABLES (STAGING LAYER)
-- 1A. Facebook Ads — raw staging table
CREATE TABLE IF NOT EXISTS `marketing_analytics.stg_facebook_ads` (
    date            DATE            NOT NULL,
    campaign_id     STRING          NOT NULL,
    campaign_name   STRING          NOT NULL,
    ad_set_id       STRING          NOT NULL,
    ad_set_name     STRING          NOT NULL,
    impressions     INT64           NOT NULL,
    clicks          INT64           NOT NULL,
    spend           FLOAT64         NOT NULL,
    conversions     INT64           NOT NULL,
    video_views     INT64,
    engagement_rate FLOAT64,
    reach           INT64,
    frequency       FLOAT64
);

-- 1B. Google Ads — raw staging table
CREATE TABLE IF NOT EXISTS `marketing_analytics.stg_google_ads` (
    date                    DATE            NOT NULL,
    campaign_id             STRING          NOT NULL,
    campaign_name           STRING          NOT NULL,
    ad_group_id             STRING          NOT NULL,
    ad_group_name           STRING          NOT NULL,
    impressions             INT64           NOT NULL,
    clicks                  INT64           NOT NULL,
    cost                    FLOAT64         NOT NULL,
    conversions             INT64           NOT NULL,
    conversion_value        FLOAT64,
    ctr                     FLOAT64,
    avg_cpc                 FLOAT64,
    quality_score           INT64,
    search_impression_share FLOAT64
);

-- 1C. TikTok Ads — raw staging table
CREATE TABLE IF NOT EXISTS `marketing_analytics.stg_tiktok_ads` (
    date            DATE            NOT NULL,
    campaign_id     STRING          NOT NULL,
    campaign_name   STRING          NOT NULL,
    adgroup_id      STRING          NOT NULL,
    adgroup_name    STRING          NOT NULL,
    impressions     INT64           NOT NULL,
    clicks          INT64           NOT NULL,
    cost            FLOAT64         NOT NULL,
    conversions     INT64           NOT NULL,
    video_views     INT64,
    video_watch_25  INT64,
    video_watch_50  INT64,
    video_watch_75  INT64,
    video_watch_100 INT64,
    likes           INT64,
    shares          INT64,
    comments        INT64
);



-- STEP 2: UNIFIED CROSS-CHANNEL MODEL (MART LAYER)

CREATE OR REPLACE TABLE `marketing_analytics.unified_ad_performance` AS

WITH facebook_normalized AS (
    SELECT
        date,
        'facebook'                          AS platform,
        campaign_id,
        campaign_name,
        ad_set_id                           AS ad_group_id,
        ad_set_name                         AS ad_group_name,
        impressions,
        clicks,
        spend,
        conversions,
        SAFE_DIVIDE(clicks, impressions)    AS ctr,
        SAFE_DIVIDE(spend, clicks)          AS cpc,
        SAFE_DIVIDE(spend, conversions)     AS cpa,
        SAFE_DIVIDE(conversions, clicks)    AS cvr,
        video_views,
        engagement_rate,
        reach,
        frequency,
        CAST(NULL AS FLOAT64)               AS conversion_value,
        CAST(NULL AS INT64)                 AS quality_score,
        CAST(NULL AS FLOAT64)               AS search_impression_share,
        CAST(NULL AS INT64)                 AS video_watch_25,
        CAST(NULL AS INT64)                 AS video_watch_50,
        CAST(NULL AS INT64)                 AS video_watch_75,
        CAST(NULL AS INT64)                 AS video_watch_100,
        CAST(NULL AS INT64)                 AS likes,
        CAST(NULL AS INT64)                 AS shares,
        CAST(NULL AS INT64)                 AS comments

    FROM `marketing_analytics.stg_facebook_ads`
),

google_normalized AS (
    SELECT
        date,
        'google'                            AS platform,
        campaign_id,
        campaign_name,
        ad_group_id,
        ad_group_name,
        impressions,
        clicks,
        cost                                AS spend,
        conversions,
        SAFE_DIVIDE(clicks, impressions)    AS ctr,
        SAFE_DIVIDE(cost, clicks)           AS cpc,
        SAFE_DIVIDE(cost, conversions)      AS cpa,
        SAFE_DIVIDE(conversions, clicks)    AS cvr,
        CAST(NULL AS INT64)                 AS video_views,
        CAST(NULL AS FLOAT64)              AS engagement_rate,
        CAST(NULL AS INT64)                 AS reach,
        CAST(NULL AS FLOAT64)               AS frequency,
        conversion_value,
        quality_score,
        search_impression_share,
        CAST(NULL AS INT64)                 AS video_watch_25,
        CAST(NULL AS INT64)                 AS video_watch_50,
        CAST(NULL AS INT64)                 AS video_watch_75,
        CAST(NULL AS INT64)                 AS video_watch_100,
        CAST(NULL AS INT64)                 AS likes,
        CAST(NULL AS INT64)                 AS shares,
        CAST(NULL AS INT64)                 AS comments

    FROM `marketing_analytics.stg_google_ads`
),

tiktok_normalized AS (
    SELECT
        date,
        'tiktok'                            AS platform,
        campaign_id,
        campaign_name,
        adgroup_id                          AS ad_group_id,
        adgroup_name                        AS ad_group_name,
        impressions,
        clicks,
        cost                                AS spend,
        conversions,
        SAFE_DIVIDE(clicks, impressions)    AS ctr,
        SAFE_DIVIDE(cost, clicks)           AS cpc,
        SAFE_DIVIDE(cost, conversions)      AS cpa,
        SAFE_DIVIDE(conversions, clicks)    AS cvr,
        video_views,
        CAST(NULL AS FLOAT64)              AS engagement_rate,
        CAST(NULL AS INT64)                 AS reach,
        CAST(NULL AS FLOAT64)               AS frequency,
        CAST(NULL AS FLOAT64)               AS conversion_value,
        CAST(NULL AS INT64)                 AS quality_score,
        CAST(NULL AS FLOAT64)               AS search_impression_share,
        video_watch_25,
        video_watch_50,
        video_watch_75,
        video_watch_100,
        likes,
        shares,
        comments

    FROM `marketing_analytics.stg_tiktok_ads`
),

unified AS (
    SELECT * FROM facebook_normalized
    UNION ALL
    SELECT * FROM google_normalized
    UNION ALL
    SELECT * FROM tiktok_normalized
)

SELECT * FROM unified
ORDER BY date, platform, campaign_id;

-- STEP 3: DATA QUALITY VALIDATION

-- 1A. Row count validation: source vs unified
SELECT
    'unified_total' AS check_name,
    COUNT(*) AS row_count
FROM `marketing_analytics.unified_ad_performance`

UNION ALL

SELECT
    'facebook_source' AS check_name,
    COUNT(*) AS row_count
FROM `marketing_analytics.stg_facebook_ads`

UNION ALL

SELECT
    'google_source' AS check_name,
    COUNT(*) AS row_count
FROM `marketing_analytics.stg_google_ads`

UNION ALL

SELECT
    'tiktok_source' AS check_name,
    COUNT(*) AS row_count
FROM `marketing_analytics.stg_tiktok_ads`;


-- 1B. Spend reconciliation: source totals must match unified totals
SELECT
    platform,
    SUM(spend)          AS total_spend,
    SUM(impressions)    AS total_impressions,
    SUM(clicks)         AS total_clicks,
    SUM(conversions)    AS total_conversions
FROM `marketing_analytics.unified_ad_performance`
GROUP BY platform
ORDER BY platform;


-- 1C. Check for NULL values in required (universal) columns
SELECT
    COUNTIF(date IS NULL)           AS null_dates,
    COUNTIF(platform IS NULL)       AS null_platforms,
    COUNTIF(campaign_id IS NULL)    AS null_campaign_ids,
    COUNTIF(impressions IS NULL)    AS null_impressions,
    COUNTIF(clicks IS NULL)         AS null_clicks,
    COUNTIF(spend IS NULL)          AS null_spend,
    COUNTIF(conversions IS NULL)    AS null_conversions
FROM `marketing_analytics.unified_ad_performance`;


-- 1D. Derived metric spot-check: CTR should equal clicks/impressions
SELECT
    platform,
    date,
    campaign_id,
    ctr AS computed_ctr,
    SAFE_DIVIDE(clicks, impressions) AS verified_ctr,
    ABS(ctr - SAFE_DIVIDE(clicks, impressions)) AS diff
FROM `marketing_analytics.unified_ad_performance`
WHERE ABS(ctr - SAFE_DIVIDE(clicks, impressions)) > 0.0001
LIMIT 10;

-- STEP 3: VIEWS FOR DASHBOARD
-- 1A. Daily cross-channel summary (primary dashboard data source)
CREATE OR REPLACE VIEW `marketing_analytics.v_daily_channel_summary` AS
SELECT
    date,
    platform,
    SUM(impressions)                        AS impressions,
    SUM(clicks)                             AS clicks,
    SUM(spend)                              AS spend,
    SUM(conversions)                        AS conversions,
    SAFE_DIVIDE(SUM(clicks), SUM(impressions))   AS ctr,
    SAFE_DIVIDE(SUM(spend), SUM(clicks))         AS cpc,
    SAFE_DIVIDE(SUM(spend), SUM(conversions))    AS cpa,
    SAFE_DIVIDE(SUM(conversions), SUM(clicks))   AS cvr,
    -- Platform-specific aggregations
    SUM(video_views)                        AS video_views,
    SUM(conversion_value)                   AS conversion_value,
    SUM(likes)                              AS likes,
    SUM(shares)                             AS shares,
    SUM(comments)                           AS comments
FROM `marketing_analytics.unified_ad_performance`
GROUP BY date, platform;


-- 1B. Campaign performance summary (campaign-level drill-down)
CREATE OR REPLACE VIEW `marketing_analytics.v_campaign_performance` AS
SELECT
    platform,
    campaign_id,
    campaign_name,
    COUNT(DISTINCT date)                            AS active_days,
    SUM(impressions)                                AS impressions,
    SUM(clicks)                                     AS clicks,
    SUM(spend)                                      AS spend,
    SUM(conversions)                                AS conversions,
    SAFE_DIVIDE(SUM(clicks), SUM(impressions))      AS ctr,
    SAFE_DIVIDE(SUM(spend), SUM(clicks))            AS cpc,
    SAFE_DIVIDE(SUM(spend), SUM(conversions))       AS cpa,
    SAFE_DIVIDE(SUM(conversions), SUM(clicks))      AS cvr,
    SAFE_DIVIDE(SUM(spend), SUM(impressions)) * 1000 AS cpm
FROM `marketing_analytics.unified_ad_performance`
GROUP BY platform, campaign_id, campaign_name;


-- 1C. Overall platform comparison (top-level KPI cards)
CREATE OR REPLACE VIEW `marketing_analytics.v_platform_summary` AS
SELECT
    platform,
    SUM(spend)                                      AS total_spend,
    SUM(impressions)                                AS total_impressions,
    SUM(clicks)                                     AS total_clicks,
    SUM(conversions)                                AS total_conversions,
    SAFE_DIVIDE(SUM(clicks), SUM(impressions))      AS avg_ctr,
    SAFE_DIVIDE(SUM(spend), SUM(clicks))            AS avg_cpc,
    SAFE_DIVIDE(SUM(spend), SUM(conversions))       AS avg_cpa,
    SAFE_DIVIDE(SUM(conversions), SUM(clicks))      AS avg_cvr,
    SAFE_DIVIDE(SUM(spend), SUM(impressions)) * 1000 AS avg_cpm,
    SAFE_DIVIDE(
        SUM(spend),
        (SELECT SUM(spend) FROM `marketing_analytics.unified_ad_performance`)
    ) AS spend_share,
    SAFE_DIVIDE(
        SUM(conversions),
        (SELECT SUM(conversions) FROM `marketing_analytics.unified_ad_performance`)
    ) AS conversion_share
FROM `marketing_analytics.unified_ad_performance`
GROUP BY platform;


-- 1D. Weekly trend (for trend line in dashboard)
CREATE OR REPLACE VIEW `marketing_analytics.v_weekly_trend` AS
SELECT
    DATE_TRUNC(date, WEEK(MONDAY))                  AS week_start,
    platform,
    SUM(spend)                                      AS spend,
    SUM(impressions)                                AS impressions,
    SUM(clicks)                                     AS clicks,
    SUM(conversions)                                AS conversions,
    SAFE_DIVIDE(SUM(spend), SUM(conversions))       AS cpa,
    SAFE_DIVIDE(SUM(clicks), SUM(impressions))      AS ctr,
    SAFE_DIVIDE(SUM(spend), SUM(clicks))            AS cpc
FROM `marketing_analytics.unified_ad_performance`
GROUP BY week_start, platform;


-- 1E. TikTok video funnel (platform-specific deep dive)
CREATE OR REPLACE VIEW `marketing_analytics.v_tiktok_video_funnel` AS
SELECT
    campaign_name,
    SUM(video_views)                                        AS total_views,
    SUM(video_watch_25)                                     AS watch_25_pct,
    SUM(video_watch_50)                                     AS watch_50_pct,
    SUM(video_watch_75)                                     AS watch_75_pct,
    SUM(video_watch_100)                                    AS watch_100_pct,
    SAFE_DIVIDE(SUM(video_watch_25), SUM(video_views))      AS rate_25,
    SAFE_DIVIDE(SUM(video_watch_50), SUM(video_views))      AS rate_50,
    SAFE_DIVIDE(SUM(video_watch_75), SUM(video_views))      AS rate_75,
    SAFE_DIVIDE(SUM(video_watch_100), SUM(video_views))     AS rate_100
FROM `marketing_analytics.unified_ad_performance`
WHERE platform = 'tiktok'
GROUP BY campaign_name;
