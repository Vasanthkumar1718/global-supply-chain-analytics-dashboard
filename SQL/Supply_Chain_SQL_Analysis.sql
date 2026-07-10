/*
=====================================================================================================
    File        : 04_SQL_Analysis.sql
    Project     : Global Supply Chain Analysis
    Description : Business analysis using PostgreSQL
                  Covers: Operational performance, freight costs,
                          trade routes, shipping delays, and logistics KPIs.

    Database    : supply_chain_analysis
    Tables       : operations,
                   trade_routes,
                   commodity_market,
                   geopolitical_events,
                   weekly_timeline,
                   country_metadata

    Note        : This script answers business questions using SQL.
                  No data cleaning or transformations are performed.
=====================================================================================================

*/





-- ============================================
-- Q1. Which trade routes generate the highest total freight cost?
-- ============================================

SELECT
    route_id,
    ROUND(SUM(freight_cost_usd)::NUMERIC, 2) AS total_freight_cost
FROM operations
GROUP BY route_id
ORDER BY total_freight_cost DESC
LIMIT 10;

-- ============================================
-- Q2. Which trade routes are at the highest operational risk?
-- ============================================
SELECT
    route_id,
    ROUND(AVG(geopolitical_risk_score)::NUMERIC, 2) AS avg_geopolitical_risk,
    ROUND(AVG(weather_disruption_score)::NUMERIC, 2) AS avg_weather_risk,
    ROUND(AVG(port_congestion_index)::NUMERIC, 2) AS avg_port_congestion,
    ROUND(AVG(shipping_delay_days)::NUMERIC, 2) AS avg_shipping_delay
FROM operations
GROUP BY route_id
ORDER BY
    avg_geopolitical_risk DESC,
    avg_weather_risk DESC,
    avg_port_congestion DESC,
    avg_shipping_delay DESC
LIMIT 10;

-- ============================================
-- Q3. Which trade routes experience the highest percentage of delayed and disrupted shipments?
SELECT
    route_id,
    COUNT(*) AS total_shipments,
    SUM(
        CASE
            WHEN route_status IN ('Delayed', 'Disrupted') THEN 1
            ELSE 0
        END
    ) AS affected_shipments,
    ROUND(
        100.0 * SUM(
            CASE
                WHEN route_status IN ('Delayed', 'Disrupted') THEN 1
                ELSE 0
            END
        ) / COUNT(*),
        2
    ) AS affected_percentage
FROM operations
GROUP BY route_id
ORDER BY affected_percentage DESC, total_shipments DESC
LIMIT 10;
-- ============================================
-- ============================================
-- Q4. Which countries have the highest average freight cost?
-- ============================================

SELECT
    tr.origin_country,
    ROUND(AVG(o.freight_cost_usd)::NUMERIC, 2) AS avg_freight_cost
FROM operations o
INNER JOIN trade_routes tr
    ON o.route_id = tr.route_id
GROUP BY tr.origin_country
ORDER BY avg_freight_cost DESC;

-- ============================================
-- Q5. Which destination countries handle the highest total trade volume?
-- ============================================
SELECT
    tr.destination_country,
    ROUND(SUM(o.trade_volume_tonnes)::NUMERIC, 2) AS total_trade_volume
FROM operations o
INNER JOIN trade_routes tr
    ON o.route_id = tr.route_id
GROUP BY tr.destination_country
ORDER BY total_trade_volume DESC;
-- ============================================
-- Q6. Which months experience the highest average shipping delay?
-- ============================================
SELECT
    EXTRACT(MONTH FROM date) AS month,
    ROUND(AVG(shipping_delay_days)::NUMERIC, 2) AS avg_shipping_delay
FROM operations
GROUP BY month
ORDER BY avg_shipping_delay DESC;
-- ============================================
-- Q7. Rank trade routes based on average shipping delay.
-- ============================================

SELECT
    route_id,
    ROUND(AVG(shipping_delay_days)::NUMERIC, 2) AS avg_shipping_delay,
    RANK() OVER (
        ORDER BY AVG(shipping_delay_days) DESC
    ) AS delay_rank
FROM operations
GROUP BY route_id
ORDER BY delay_rank
LIMIT 10;

-- ============================================
-- Q8. Which trade routes have the highest carbon emissions per tonne of trade volume?
-- ============================================

SELECT
    route_id,
    ROUND(
        (
            SUM(carbon_emissions_tonnes) /
            SUM(trade_volume_tonnes)
        )::NUMERIC,
        4
    ) AS emissions_per_tonne
FROM operations
GROUP BY route_id
HAVING SUM(trade_volume_tonnes) > 0
ORDER BY emissions_per_tonne DESC
LIMIT 10;
-- ============================================
-- Q9. Which trade routes show the greatest week-over-week increase in shipping delays?
-- ============================================

WITH delay_trend AS (
    SELECT
        route_id,
        date,
        shipping_delay_days,
        LAG(shipping_delay_days) OVER (
            PARTITION BY route_id
            ORDER BY date
        ) AS previous_week_delay
    FROM operations
)

SELECT
    route_id,
    date,
    ROUND(shipping_delay_days::NUMERIC, 2) AS current_delay,
    ROUND(previous_week_delay::NUMERIC, 2) AS previous_delay,
    ROUND(
        (shipping_delay_days - previous_week_delay)::NUMERIC,
        2
    ) AS delay_increase
FROM delay_trend
WHERE previous_week_delay IS NOT NULL
ORDER BY delay_increase DESC
LIMIT 10;

-- ============================================
-- Q10. Classify trade routes based on average shipping delay
-- ============================================

WITH route_performance AS (
    SELECT
        route_id,
        ROUND(AVG(shipping_delay_days)::NUMERIC, 2) AS avg_shipping_delay
    FROM operations
    GROUP BY route_id
)

SELECT
    route_id,
    avg_shipping_delay,
    CASE
        WHEN avg_shipping_delay < 6.25 THEN 'Excellent'
        WHEN avg_shipping_delay < 6.40 THEN 'Good'
        WHEN avg_shipping_delay < 6.50 THEN 'Needs Attention'
        ELSE 'Critical'
    END AS performance_category
FROM route_performance
ORDER BY avg_shipping_delay DESC;