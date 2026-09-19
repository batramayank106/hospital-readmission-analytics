-- =====================================================================
-- analytics.sql : core business questions (Q1-Q15)
-- Table: encounters | Target: readmitted_30_days (1 = readmitted within 30d)
-- Usage: psql -d healthcare -f sql/analytics.sql
-- NOTE: this project studies historical encounters; it is NOT a clinical
-- decision-making system.
-- =====================================================================

-- Q1. What is the overall 30-day readmission rate?
-- Business: the headline KPI every stakeholder asks for first.
SELECT
    COUNT(*) AS total_encounters,
    SUM(readmitted_30_days) AS readmitted_30d,
    ROUND(100.0 * AVG(readmitted_30_days), 2) AS readmission_rate_pct
FROM encounters;
-- Read: ~11% of encounters came back within 30 days (imbalanced target).

-- Q2. How does readmission vary by age group?
-- Business: tells us which age cohorts carry the most return load.
SELECT age,
    COUNT(*) AS n,
    ROUND(100.0 * AVG(readmitted_30_days), 2) AS readmission_rate_pct
FROM encounters
GROUP BY age
ORDER BY readmission_rate_pct DESC;
-- Read: small [20-30) band tops the list; among large bands, 70-90s are highest.

-- Q3. How does readmission vary by gender?
SELECT gender,
    COUNT(*) AS n,
    ROUND(100.0 * AVG(readmitted_30_days), 2) AS readmission_rate_pct
FROM encounters
GROUP BY gender;
-- Read: rates are similar across genders; gender is not a big separator.

-- Q4. How does readmission vary by admission type?
-- Business: emergency vs elective pathways behave very differently.
SELECT
    CASE admission_type_id
        WHEN 1 THEN 'Emergency' WHEN 2 THEN 'Urgent' WHEN 3 THEN 'Elective'
        WHEN 4 THEN 'Newborn' WHEN 5 THEN 'Not Available' WHEN 6 THEN 'NULL'
        WHEN 7 THEN 'Trauma Center' ELSE 'Other/Not Mapped'
    END AS admission_type,
    COUNT(*) AS n,
    ROUND(100.0 * AVG(readmitted_30_days), 2) AS readmission_rate_pct
FROM encounters
GROUP BY 1
ORDER BY readmission_rate_pct DESC;
-- Read: emergency admissions return at a higher rate than elective ones.

-- Q5. How does readmission vary by discharge disposition?
-- Business: where we send patients may relate to returns; worth reviewing.
SELECT
    CASE
        WHEN discharge_disposition_id = 1 THEN 'Home'
        WHEN discharge_disposition_id = 6 THEN 'Home with home health'
        WHEN discharge_disposition_id IN (3, 4, 5) THEN 'Care facility (SNF/ICF/other)'
        WHEN discharge_disposition_id = 7 THEN 'Left AMA'
        WHEN discharge_disposition_id IN (11, 19, 20, 21) THEN 'Expired/hospice-expired'
        WHEN discharge_disposition_id IN (13, 14) THEN 'Hospice'
        ELSE 'Other/transfer'
    END AS discharge_group,
    COUNT(*) AS n,
    ROUND(100.0 * AVG(readmitted_30_days), 2) AS readmission_rate_pct
FROM encounters
GROUP BY 1
ORDER BY readmission_rate_pct DESC;
-- Read: some discharge routes (e.g. transfers, AMA) show higher return rates.

-- Q6. Average length of stay: readmitted vs non-readmitted?
SELECT
    CASE WHEN readmitted_30_days = 1 THEN 'Readmitted (<30d)' ELSE 'Not readmitted' END AS cohort,
    COUNT(*) AS n,
    ROUND(AVG(time_in_hospital), 2) AS avg_stay_days,
    ROUND(AVG(num_lab_procedures), 1) AS avg_lab_procedures
FROM encounters
GROUP BY 1;
-- Read: readmitted encounters skew slightly longer with more lab procedures.

-- Q7. How does the number of diagnoses relate to readmission?
SELECT diagnosis_count_band AS diagnosis_band,
    COUNT(*) AS n,
    ROUND(100.0 * AVG(readmitted_30_days), 2) AS readmission_rate_pct
FROM encounters
GROUP BY 1
ORDER BY readmission_rate_pct DESC;
-- Read: High (7+) diagnosis counts carry the highest return rate.

-- Q8. How does medication count relate to readmission?
SELECT medication_count_band AS medication_band,
    COUNT(*) AS n,
    ROUND(100.0 * AVG(readmitted_30_days), 2) AS readmission_rate_pct
FROM encounters
GROUP BY 1
ORDER BY readmission_rate_pct DESC;
-- Read: heavier medication loads (21+) align with higher readmission.

-- Q9. How do previous inpatient visits relate to readmission?
SELECT prior_inpatient_visit_band AS prior_inpatient,
    COUNT(*) AS n,
    ROUND(100.0 * AVG(readmitted_30_days), 2) AS readmission_rate_pct
FROM encounters
GROUP BY 1
ORDER BY 1;
-- Read: patients with 2+ prior inpatient stays return far more often.

-- Q10. How do previous emergency visits relate to readmission?
SELECT
    CASE
        WHEN number_emergency = 0 THEN '0'
        WHEN number_emergency = 1 THEN '1'
        ELSE '2+'
    END AS prior_emergency,
    COUNT(*) AS n,
    ROUND(100.0 * AVG(readmitted_30_days), 2) AS readmission_rate_pct
FROM encounters
GROUP BY 1
ORDER BY 1;
-- Read: repeat emergency users show notably higher return rates.

-- Q11. Which age groups have the highest readmission rate? (Top 3)
SELECT age,
    COUNT(*) AS n,
    ROUND(100.0 * AVG(readmitted_30_days), 2) AS readmission_rate_pct
FROM encounters
GROUP BY age
ORDER BY readmission_rate_pct DESC
LIMIT 3;
-- Read: [20-30) leads on rate (small group); 80-90 and 70-80 lead among big groups.

-- Q12. Which admission types have the highest readmission rate?
SELECT admission_type_id,
    COUNT(*) AS n,
    ROUND(100.0 * AVG(readmitted_30_days), 2) AS readmission_rate_pct
FROM encounters
GROUP BY admission_type_id
HAVING COUNT(*) > 500
ORDER BY readmission_rate_pct DESC;
-- Read: HAVING keeps only admission types with meaningful volume.

-- Q13. Which discharge categories have high readmission rates? (conditional aggregation)
-- Business: one-row comparison of key discharge routes.
SELECT
    ROUND(100.0 * AVG(CASE WHEN discharge_disposition_id = 1 THEN readmitted_30_days END), 2) AS home_rate_pct,
    ROUND(100.0 * AVG(CASE WHEN discharge_disposition_id = 6 THEN readmitted_30_days END), 2) AS home_health_rate_pct,
    ROUND(100.0 * AVG(CASE WHEN discharge_disposition_id IN (3,4,5) THEN readmitted_30_days END), 2) AS facility_rate_pct,
    ROUND(100.0 * AVG(CASE WHEN discharge_disposition_id = 7 THEN readmitted_30_days END), 2) AS ama_rate_pct
FROM encounters;
-- Read: conditional aggregation compares routes side-by-side in one row.

-- Q14. What proportion of encounters belong to high-utilization patients?
-- Business: sizes the repeat-user population for capacity planning.
SELECT high_utilization_flag,
    COUNT(*) AS n,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_encounters,
    ROUND(100.0 * AVG(readmitted_30_days), 2) AS readmission_rate_pct
FROM encounters
GROUP BY high_utilization_flag;
-- Read: a small high-utilization slice drives a disproportionate return rate.

-- Q15. Compare low vs high diagnosis counts (subquery for cohort comparison).
SELECT cohort, n, readmission_rate_pct
FROM (
    SELECT 'Low (1-3)' AS cohort, COUNT(*) AS n,
        ROUND(100.0 * AVG(readmitted_30_days), 2) AS readmission_rate_pct
    FROM encounters WHERE diagnosis_count_band = 'Low (1-3)'
    UNION ALL
    SELECT 'High (7+)', COUNT(*),
        ROUND(100.0 * AVG(readmitted_30_days), 2)
    FROM encounters WHERE diagnosis_count_band = 'High (7+)'
) t;
-- Read: subqueries build the two cohorts, outer query presents them together.
