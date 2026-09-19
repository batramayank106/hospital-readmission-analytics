-- =====================================================================
-- advanced_analytics.sql : deeper business questions (Q16-Q25)
-- Uses CTEs, subqueries, conditional aggregation and window functions.
-- Usage: psql -d healthcare -f sql/advanced_analytics.sql
-- =====================================================================

-- Q16. Compare low vs high medication counts.
SELECT cohort, n, readmission_rate_pct
FROM (
    SELECT 'Low (1-10)' AS cohort, COUNT(*) AS n,
        ROUND(100.0 * AVG(readmitted_30_days), 2) AS readmission_rate_pct
    FROM encounters WHERE medication_count_band = 'Low (1-10)'
    UNION ALL
    SELECT 'High (21+)', COUNT(*),
        ROUND(100.0 * AVG(readmitted_30_days), 2)
    FROM encounters WHERE medication_count_band = 'High (21+)'
) t;
-- Read: high-medication encounters return at a higher rate (complexity signal).

-- Q17. Readmission across length-of-stay groups.
SELECT length_of_stay_band AS stay_band,
    COUNT(*) AS n,
    ROUND(100.0 * AVG(readmitted_30_days), 2) AS readmission_rate_pct
FROM encounters
GROUP BY 1
ORDER BY MIN(time_in_hospital);
-- Read: long stays (5+ days) show the highest return rate.

-- Q18. Rank age groups by readmission rate (window function).
-- Business: a ranked list is easy to put on a slide for leadership.
SELECT age,
    n,
    readmission_rate_pct,
    RANK() OVER (ORDER BY readmission_rate_pct DESC) AS rate_rank
FROM (
    SELECT age, COUNT(*) AS n,
        ROUND(100.0 * AVG(readmitted_30_days), 2) AS readmission_rate_pct
    FROM encounters
    GROUP BY age
) t
ORDER BY rate_rank;
-- Read: RANK() orders cohorts without losing the underlying numbers.

-- Q19. Rank admission types WITHIN each age group (partitioned window).
-- Business: shows whether emergency is risky at every age or only some.
WITH age_adm AS (
    SELECT age, admission_type_id,
        COUNT(*) AS n,
        ROUND(100.0 * AVG(readmitted_30_days), 2) AS readmission_rate_pct
    FROM encounters
    GROUP BY age, admission_type_id
)
SELECT age, admission_type_id, n, readmission_rate_pct,
    RANK() OVER (PARTITION BY age ORDER BY readmission_rate_pct DESC) AS rank_in_age
FROM age_adm
ORDER BY age, rank_in_age;
-- Read: PARTITION BY restarts the ranking for each age band.
-- Note: tiny groups (n < 30) can show extreme rates; focus on large-n rows.

-- Q20. Summary table: major readmission metrics by age (CTE).
-- Business: one table combining volume, rate and stay for planning.
WITH age_stats AS (
    SELECT age,
        COUNT(*) AS encounters,
        SUM(readmitted_30_days) AS readmitted,
        ROUND(100.0 * AVG(readmitted_30_days), 2) AS rate_pct,
        ROUND(AVG(time_in_hospital), 2) AS avg_stay
    FROM encounters
    GROUP BY age
)
SELECT * FROM age_stats ORDER BY rate_pct DESC;
-- Read: CTE keeps the aggregation readable; final SELECT presents it.

-- Q21. Cohorts above the overall average (CTE + scalar subquery).
-- Business: "which groups beat the average?" is the classic BA question.
WITH overall AS (
    SELECT AVG(readmitted_30_days) AS avg_rate FROM encounters
),
cohort AS (
    SELECT age, COUNT(*) AS n,
        AVG(readmitted_30_days) AS rate
    FROM encounters
    GROUP BY age
)
SELECT c.age, c.n, ROUND(100.0 * c.rate, 2) AS rate_pct
FROM cohort c CROSS JOIN overall o
WHERE c.rate > o.avg_rate
ORDER BY c.rate DESC;
-- Read: CROSS JOIN brings the single overall average onto every row for comparison.

-- Q22. Each age cohort's contribution to TOTAL readmissions.
-- Business: rate tells risk, contribution tells workload impact.
SELECT age,
    COUNT(*) AS n,
    SUM(readmitted_30_days) AS readmitted,
    ROUND(100.0 * SUM(readmitted_30_days) / SUM(SUM(readmitted_30_days)) OVER (), 2)
        AS pct_of_all_readmissions
FROM encounters
GROUP BY age
ORDER BY pct_of_all_readmissions DESC;
-- Read: the 60-80 bands dominate both rate AND total return volume.

-- Q23. Emergency utilization vs readmission (JOIN of two aggregates).
-- Business: joins let us compare prior-ER behaviour against outcomes.
SELECT e.prior_emergency, e.n, e.rate_pct, o.avg_outpatient_visits
FROM (
    SELECT CASE WHEN number_emergency = 0 THEN 'No prior ER'
                WHEN number_emergency = 1 THEN '1 prior ER'
                ELSE '2+ prior ER' END AS prior_emergency,
        COUNT(*) AS n,
        ROUND(100.0 * AVG(readmitted_30_days), 2) AS rate_pct
    FROM encounters GROUP BY 1
) e
JOIN (
    SELECT CASE WHEN number_emergency = 0 THEN 'No prior ER'
                WHEN number_emergency = 1 THEN '1 prior ER'
                ELSE '2+ prior ER' END AS prior_emergency,
        ROUND(AVG(number_outpatient), 2) AS avg_outpatient_visits
    FROM encounters GROUP BY 1
) o USING (prior_emergency)
ORDER BY e.rate_pct DESC;
-- Read: repeat-ER patients also use more outpatient care yet still return more.

-- Q24. Prior inpatient visits and readmission (CTE with conditional split).
WITH inp AS (
    SELECT
        CASE WHEN number_inpatient = 0 THEN 'No prior inpatient'
             ELSE 'Prior inpatient (1+)' END AS cohort,
        readmitted_30_days
    FROM encounters
)
SELECT cohort,
    COUNT(*) AS n,
    ROUND(100.0 * AVG(readmitted_30_days), 2) AS rate_pct
FROM inp
GROUP BY cohort;
-- Read: any prior inpatient stay roughly doubles the historical return rate.

-- Q25. FINAL: one-row executive summary of the most important business metrics.
-- Business: the single query you show in the last interview slide.
SELECT
    COUNT(*) AS total_encounters,
    COUNT(DISTINCT patient_nbr) AS unique_patients,
    ROUND(100.0 * AVG(readmitted_30_days), 2) AS overall_readmit_pct,
    ROUND(AVG(time_in_hospital), 2) AS avg_stay_days,
    ROUND(100.0 * AVG(high_utilization_flag), 2) AS high_util_pct,
    ROUND(100.0 * AVG(CASE WHEN prior_inpatient_visit_band = '2+'
        THEN readmitted_30_days END), 2) AS prior_2plus_rate_pct,
    ROUND(100.0 * AVG(CASE WHEN age IN ('[60-70)','[70-80)','[80-90)')
        THEN readmitted_30_days END), 2) AS age_60plus_rate_pct
FROM encounters;
-- Read: volume, rate, stay, high-use share and the two riskiest cohorts in one row.
