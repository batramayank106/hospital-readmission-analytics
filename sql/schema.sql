-- =====================================================================
-- schema.sql : main analytical table for the readmission project
-- Database: healthcare | Table: encounters (one row = one hospital encounter)
-- Usage: psql -h localhost -p 5433 -U postgres -d healthcare -f sql/schema.sql
-- NOTE: historical encounters only; NOT a clinical decision-making system.
-- =====================================================================

DROP TABLE IF EXISTS encounters;

CREATE TABLE encounters (
    patient_nbr                 BIGINT,
    race                        TEXT,
    gender                      TEXT,
    age                         TEXT,
    admission_type_id           INTEGER,
    discharge_disposition_id    INTEGER,
    admission_source_id         INTEGER,
    time_in_hospital            INTEGER,
    num_lab_procedures          INTEGER,
    num_procedures              INTEGER,
    num_medications             INTEGER,
    number_outpatient           INTEGER,
    number_emergency            INTEGER,
    number_inpatient            INTEGER,
    diag_1                      TEXT,
    diag_2                      TEXT,
    diag_3                      TEXT,
    number_diagnoses            INTEGER,
    max_glu_serum               TEXT,
    "A1Cresult"                 TEXT,
    metformin                   TEXT,
    repaglinide                 TEXT,
    nateglinide                 TEXT,
    glimepiride                 TEXT,
    glipizide                   TEXT,
    glyburide                   TEXT,
    pioglitazone                TEXT,
    rosiglitazone               TEXT,
    insulin                     TEXT,
    "glyburide-metformin"       TEXT,
    change                      TEXT,
    "diabetesMed"               TEXT,
    readmitted_30_days          INTEGER,   -- 1 = readmitted within 30 days
    age_group                   TEXT,
    diagnosis_count_band        TEXT,
    medication_count_band       TEXT,
    prior_inpatient_visit_band  TEXT,
    length_of_stay_band         TEXT,
    high_utilization_flag       INTEGER    -- 1 = 3+ prior-year visits
);

CREATE INDEX idx_encounters_target ON encounters (readmitted_30_days);
CREATE INDEX idx_encounters_age ON encounters (age);
