"""
SQL QUERIES FOR NFL PRESSURE ANALYSIS
Author: Gurkamal Cheema

These queries demonstrate how to extract insights from NFL play-by-play data
using SQL. In a real Big Data Bowl scenario, these would be run against 
NFL tracking databases containing millions of player position records.
"""

-- ============================================================================
-- QUERY 1: Overall Pressure Impact on QB Performance
-- ============================================================================
-- This query calculates key QB metrics with and without defensive pressure

SELECT 
    CASE 
        WHEN pressure_applied = 1 THEN 'Pressure Applied'
        ELSE 'No Pressure'
    END AS pressure_status,
    COUNT(*) AS total_plays,
    ROUND(AVG(CASE WHEN completion = 1 THEN 1.0 ELSE 0.0 END) * 100, 1) AS completion_pct,
    ROUND(AVG(yards_gained), 2) AS avg_yards_per_attempt,
    ROUND(AVG(CASE WHEN sack = 1 THEN 1.0 ELSE 0.0 END) * 100, 2) AS sack_rate,
    ROUND(AVG(CASE WHEN interception = 1 THEN 1.0 ELSE 0.0 END) * 100, 2) AS int_rate
FROM 
    qb_pressure_data
GROUP BY 
    pressure_applied
ORDER BY 
    pressure_applied;

-- EXPECTED OUTPUT:
-- pressure_status   | total_plays | completion_pct | avg_yards_per_attempt | sack_rate | int_rate
-- ------------------+-------------+----------------+-----------------------+-----------+---------
-- No Pressure       |        1673 |           67.8 |                  4.66 |      0.00 |     0.00
-- Pressure Applied  |         827 |           43.5 |                  2.05 |      0.00 |     0.00


-- ============================================================================
-- QUERY 2: Optimal Pressure Timing Analysis
-- ============================================================================
-- Determines which pressure timing windows are most effective

WITH pressure_plays AS (
    SELECT 
        *,
        CASE 
            WHEN time_to_pressure < 1.5 THEN 'Immediate (<1.5s)'
            WHEN time_to_pressure < 2.5 THEN 'Quick (1.5-2.5s)'
            WHEN time_to_pressure < 3.5 THEN 'Delayed (2.5-3.5s)'
            ELSE 'Late (>3.5s)'
        END AS pressure_timing,
        CASE 
            WHEN completion = 0 OR sack = 1 OR interception = 1 THEN 1
            ELSE 0
        END AS successful_pressure
    FROM qb_pressure_data
    WHERE pressure_applied = 1
)
SELECT 
    pressure_timing,
    COUNT(*) AS total_pressures,
    ROUND(AVG(successful_pressure) * 100, 1) AS success_rate,
    ROUND(AVG(CASE WHEN sack = 1 THEN 1.0 ELSE 0.0 END) * 100, 2) AS sack_rate,
    ROUND(AVG(yards_gained), 2) AS avg_yards_allowed
FROM 
    pressure_plays
GROUP BY 
    pressure_timing
ORDER BY 
    success_rate DESC;


-- ============================================================================
-- QUERY 3: Defensive Alignment Effectiveness
-- ============================================================================
-- Compares success rates of different defensive formations when pressuring

SELECT 
    def_alignment,
    COUNT(*) AS pressure_attempts,
    ROUND(AVG(CASE WHEN sack = 1 THEN 1.0 ELSE 0.0 END) * 100, 2) AS sack_rate,
    ROUND(AVG(CASE WHEN completion = 0 THEN 1.0 ELSE 0.0 END) * 100, 1) AS incompletion_rate,
    ROUND(AVG(CASE WHEN interception = 1 THEN 1.0 ELSE 0.0 END) * 100, 2) AS int_rate,
    ROUND(AVG(yards_gained), 2) AS avg_yards_allowed
FROM 
    qb_pressure_data
WHERE 
    pressure_applied = 1
GROUP BY 
    def_alignment
ORDER BY 
    sack_rate DESC, incompletion_rate DESC;


-- ============================================================================
-- QUERY 4: Time to Throw vs. Success Rate
-- ============================================================================
-- Analyzes how QB release time affects completion rate under different scenarios

SELECT 
    CASE 
        WHEN time_to_throw < 2.0 THEN 'Quick (<2.0s)'
        WHEN time_to_throw < 2.5 THEN 'Normal (2.0-2.5s)'
        WHEN time_to_throw < 3.0 THEN 'Extended (2.5-3.0s)'
        ELSE 'Very Long (>3.0s)'
    END AS release_time,
    CASE 
        WHEN pressure_applied = 1 THEN 'Pressure'
        ELSE 'No Pressure'
    END AS pressure_status,
    COUNT(*) AS total_plays,
    ROUND(AVG(CASE WHEN completion = 1 THEN 1.0 ELSE 0.0 END) * 100, 1) AS completion_pct,
    ROUND(AVG(yards_gained), 2) AS avg_yards
FROM 
    qb_pressure_data
GROUP BY 
    release_time, pressure_applied
ORDER BY 
    release_time, pressure_applied;


-- ============================================================================
-- QUERY 5: Situational Pressure Analysis (Down & Distance)
-- ============================================================================
-- Examines pressure effectiveness across different game situations

SELECT 
    down,
    CASE 
        WHEN distance < 3 THEN 'Short (<3 yards)'
        WHEN distance < 7 THEN 'Medium (3-7 yards)'
        WHEN distance < 15 THEN 'Long (7-15 yards)'
        ELSE 'Very Long (>15 yards)'
    END AS distance_category,
    COUNT(*) AS total_plays,
    ROUND(AVG(CASE WHEN pressure_applied = 1 THEN 1.0 ELSE 0.0 END) * 100, 1) AS pressure_rate,
    ROUND(AVG(CASE WHEN completion = 1 THEN 1.0 ELSE 0.0 END) * 100, 1) AS completion_pct,
    ROUND(AVG(yards_gained), 2) AS avg_yards
FROM 
    qb_pressure_data
GROUP BY 
    down, distance_category
ORDER BY 
    down, distance_category;


-- ============================================================================
-- QUERY 6: Pressure Success by Number of Pass Rushers
-- ============================================================================
-- Determines optimal number of pass rushers for generating pressure

SELECT 
    rushers AS num_pass_rushers,
    COUNT(*) AS total_plays,
    ROUND(AVG(CASE WHEN pressure_applied = 1 THEN 1.0 ELSE 0.0 END) * 100, 1) AS pressure_rate,
    ROUND(AVG(CASE WHEN sack = 1 THEN 1.0 ELSE 0.0 END) * 100, 2) AS sack_rate,
    ROUND(AVG(CASE WHEN completion = 0 THEN 1.0 ELSE 0.0 END) * 100, 1) AS incompletion_rate
FROM 
    qb_pressure_data
WHERE 
    pressure_applied = 1
GROUP BY 
    rushers
ORDER BY 
    rushers;


-- ============================================================================
-- QUERY 7: Advanced Metric - Expected Value Added by Pressure
-- ============================================================================
-- Calculates the difference in expected yards between pressure/no pressure scenarios

WITH avg_by_situation AS (
    SELECT 
        down,
        CASE 
            WHEN distance < 5 THEN 'Short'
            WHEN distance < 10 THEN 'Medium'
            ELSE 'Long'
        END AS dist_cat,
        pressure_applied,
        AVG(yards_gained) AS avg_yards
    FROM qb_pressure_data
    GROUP BY down, dist_cat, pressure_applied
)
SELECT 
    down,
    dist_cat,
    MAX(CASE WHEN pressure_applied = 0 THEN avg_yards END) AS yards_no_pressure,
    MAX(CASE WHEN pressure_applied = 1 THEN avg_yards END) AS yards_with_pressure,
    ROUND(
        MAX(CASE WHEN pressure_applied = 0 THEN avg_yards END) - 
        MAX(CASE WHEN pressure_applied = 1 THEN avg_yards END), 
        2
    ) AS yards_prevented_by_pressure
FROM avg_by_situation
GROUP BY down, dist_cat
ORDER BY yards_prevented_by_pressure DESC;


-- ============================================================================
-- QUERY 8: Identifying High-Value Pressure Opportunities
-- ============================================================================
-- Finds game situations where pressure has the biggest impact

SELECT 
    quarter,
    CASE 
        WHEN score_diff > 7 THEN 'Winning by 8+'
        WHEN score_diff > 0 THEN 'Winning by 1-7'
        WHEN score_diff = 0 THEN 'Tied'
        WHEN score_diff > -7 THEN 'Losing by 1-7'
        ELSE 'Losing by 8+'
    END AS score_situation,
    COUNT(*) AS pressure_plays,
    ROUND(AVG(CASE WHEN completion = 0 OR sack = 1 THEN 1.0 ELSE 0.0 END) * 100, 1) AS defensive_success_rate,
    ROUND(AVG(yards_gained), 2) AS avg_yards_allowed
FROM 
    qb_pressure_data
WHERE 
    pressure_applied = 1
GROUP BY 
    quarter, score_situation
HAVING 
    COUNT(*) > 10  -- Only include situations with sufficient sample size
ORDER BY 
    defensive_success_rate DESC;


-- ============================================================================
-- NOTES FOR IMPLEMENTATION
-- ============================================================================
-- 
-- In a production environment with actual NFL tracking data:
--
-- 1. These queries would run against tables like:
--    - tracking_data (player coordinates, speed, acceleration by frame)
--    - plays (play-level metadata)
--    - games (game information)
--    - players (player demographics)
--
-- 2. Performance optimization:
--    - Index on (gameId, playId, pressure_applied)
--    - Partition tables by week/season
--    - Use materialized views for commonly aggregated metrics
--
-- 3. Additional analyses possible with tracking data:
--    - QB pocket movement patterns
--    - Defensive line gap integrity
--    - Coverage shell impact on pressure success
--    - Player-specific pressure resistance metrics
--
-- ============================================================================
