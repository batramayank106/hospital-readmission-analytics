-- =====================================================================
-- data_quality.sql : checks run right after loading `encounters`
-- Usage: psql -d healthcare -f sql/data_quality.sql
-- =====================================================================

-- DQ1. Total row count (expect ~101k)
SELECT COUNT(*) AS total_rows FROM encounters;

-- DQ2. Exact duplicate rows (expect 0 after cleaning)
SELECT COUNT(*) AS duplicate_rows
FROM (
    SELECT *, COUNT(*) OVER (PARTITION BY patient_nbr, race, gender, age,
        admission_type_id, discharge_disposition_id, admission_source_id,
        time_in_hospital, num_lab_procedures, num_procedures, num_medications,
        number_outpatient, number_emergency, number_inpatient,
        diag_1, diag_2, diag_3, number_diagnoses, max_glu_serum, "A1Cresult",
        change, "diabetesMed", insulin, readmitted_30_days) AS dup_count
    FROM encounters
) t
WHERE dup_count > 1;

-- DQ3. NULL values per important column (expect 0; "?" was fixed in cleaning)
SELECT
    SUM(CASE WHEN race IS NULL THEN 1 ELSE 0 END) AS null_race,
    SUM(CASE WHEN gender IS NULL THEN 1 ELSE 0 END) AS null_gender,
    SUM(CASE WHEN age IS NULL THEN 1 ELSE 0 END) AS null_age,
    SUM(CASE WHEN diag_1 IS NULL THEN 1 ELSE 0 END) AS null_diag_1,
    SUM(CASE WHEN readmitted_30_days IS NULL THEN 1 ELSE 0 END) AS null_target
FROM encounters;

-- DQ4. Unique values of key categoricals (spot unexpected values)
SELECT 'race' AS column_name, race AS value, COUNT(*) AS n FROM encounters GROUP BY race
UNION ALL
SELECT 'gender', gender, COUNT(*) FROM encounters GROUP BY gender
UNION ALL
SELECT 'age', age, COUNT(*) FROM encounters GROUP BY age
ORDER BY column_name, n DESC;

-- DQ5. Age validity (only the 10 expected 10-year bands)
SELECT DISTINCT age FROM encounters ORDER BY age;

-- DQ6. Target distribution (expect ~11% positive, imbalanced)
SELECT readmitted_30_days,
       COUNT(*) AS n,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct
FROM encounters
GROUP BY readmitted_30_days;

-- DQ7. Numeric ranges (study rules: stay 1-14 days, diagnoses >= 1)
SELECT
    MIN(time_in_hospital) AS min_stay, MAX(time_in_hospital) AS max_stay,
    MIN(number_diagnoses) AS min_diag, MAX(number_diagnoses) AS max_diag,
    MIN(num_medications) AS min_meds, MAX(num_medications) AS max_meds,
    MIN(number_inpatient) AS min_prior_inp, MAX(number_inpatient) AS max_prior_inp
FROM encounters;
