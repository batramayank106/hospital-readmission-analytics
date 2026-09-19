"""Data cleaning for the UCI Diabetes 130-US Hospitals dataset.

Reads  : data/raw/diabetic_data.csv
Writes : data/processed/diabetes_clean.csv

Cleaning decisions (kept simple and explainable):
  1. "?" is treated as missing.
  2. Drop columns with > 30% missing (weight, payer_code, medical_specialty).
     These are mostly empty admin fields, not needed for readmission analysis.
     "None" in A1Cresult / max_glu_serum is kept: it means "test not done".
  3. Drop pure identifier columns (encounter_id). patient_nbr is kept so we
     can count repeat patients / encounters per patient.
  4. Drop medication columns that are (almost) constant - one value covers
     > 99.5% of rows, so they carry no signal.
  5. Fill remaining "?" in race / diag_1 / diag_2 / diag_3 with "Missing"
     (a real category here, not random noise).
  6. Map gender "Unknown/Invalid" -> "Unknown".
  7. Drop exact duplicate rows (kept count is reported).
  8. Fix invalid numerics: keep only rows with 1 <= time_in_hospital <= 14
     and number_diagnoses >= 1 (the study's own inclusion rules).
  9. Build target readmitted_30_days: "<30" -> 1, else 0.

Run:  python src/data_cleaning.py
"""

import numpy as np
import pandas as pd
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
RAW_PATH = PROJECT_ROOT / "data" / "raw" / "diabetic_data.csv"
PROCESSED_PATH = PROJECT_ROOT / "data" / "processed" / "diabetes_clean.csv"

HIGH_MISSING_THRESHOLD = 0.30   # drop columns with more missing than this
CONSTANT_THRESHOLD = 0.995      # drop columns where top value covers more than this


def load_raw(path: Path = RAW_PATH) -> pd.DataFrame:
    # keep_default_na=False is important: values like "None" in A1Cresult /
    # max_glu_serum mean "test not performed" (a real category), not missing.
    # Only "?" counts as missing in this dataset.
    df = pd.read_csv(path, na_values=["?"], keep_default_na=False)
    df = df.replace(r"^\s*$", np.nan, regex=True)
    return df


def cleaning_report(df_before: pd.DataFrame, df_after: pd.DataFrame,
                    dropped_cols: list, miss_before: pd.Series,
                    miss_after: pd.Series) -> None:
    print("=" * 60)
    print("DATA CLEANING REPORT")
    print("=" * 60)
    print(f"Rows before cleaning : {len(df_before)}")
    print(f"Rows after cleaning  : {len(df_after)}")
    print(f"Rows removed         : {len(df_before) - len(df_after)}")
    print(f"Columns before       : {df_before.shape[1]}")
    print(f"Columns after        : {df_after.shape[1]}")
    print(f"\nColumns removed ({len(dropped_cols)}):")
    for c in dropped_cols:
        print(f"  - {c}")
    print("\nMissing values BEFORE (top 10):")
    print((miss_before * 100).round(2).sort_values(ascending=False).head(10).to_string())
    print("\nMissing values AFTER (top 10):")
    print((miss_after * 100).round(2).sort_values(ascending=False).head(10).to_string())
    print("\nTarget distribution (readmitted_30_days):")
    print(df_after["readmitted_30_days"].value_counts(normalize=True).round(4).to_string())
    print("=" * 60)


def clean(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()
    dropped_cols = []

    # --- 1. Drop high-missing columns -------------------------------------
    miss_ratio = df.isna().mean()
    high_missing = miss_ratio[miss_ratio > HIGH_MISSING_THRESHOLD].index.tolist()
    df = df.drop(columns=high_missing)
    dropped_cols += high_missing

    # --- 2. Drop pure identifier -------------------------------------------
    if "encounter_id" in df.columns:
        df = df.drop(columns=["encounter_id"])
        dropped_cols.append("encounter_id")

    # --- 3. Drop (almost) constant columns ---------------------------------
    for col in df.columns:
        if pd.api.types.is_string_dtype(df[col]) or df[col].dtype == object:
            top_share = df[col].value_counts(normalize=True, dropna=False).iloc[0]
            if top_share > CONSTANT_THRESHOLD:
                df = df.drop(columns=[col])
                dropped_cols.append(col)

    # --- 4. Fill remaining categorical gaps --------------------------------
    for col in ["race", "diag_1", "diag_2", "diag_3", "payer_code"]:
        if col in df.columns:
            df[col] = df[col].fillna("Missing")
    if "gender" in df.columns:
        df["gender"] = df["gender"].replace({"Unknown/Invalid": "Unknown"})

    # --- 5. Drop exact duplicates ------------------------------------------
    n_dupes = df.duplicated().sum()
    print(f"Duplicate rows found: {n_dupes}")
    df = df.drop_duplicates()

    # --- 6. Fix invalid numerics (study inclusion rules) --------------------
    if "time_in_hospital" in df.columns:
        df = df[(df["time_in_hospital"] >= 1) & (df["time_in_hospital"] <= 14)]
    if "number_diagnoses" in df.columns:
        df = df[df["number_diagnoses"] >= 1]

    # --- 7. Build target -----------------------------------------------------
    df["readmitted_30_days"] = (df["readmitted"] == "<30").astype(int)
    df = df.drop(columns=["readmitted"])

    # --- 8. Tidy dtypes -------------------------------------------------------
    for col in df.columns:
        if pd.api.types.is_string_dtype(df[col]) or df[col].dtype == object:
            df[col] = df[col].astype("string").str.strip()

    return df, dropped_cols


def main() -> None:
    df_raw = load_raw()
    miss_before = df_raw.isna().mean(numeric_only=False)

    df_clean, dropped = clean(df_raw)
    miss_after = df_clean.isna().mean(numeric_only=False)

    PROCESSED_PATH.parent.mkdir(parents=True, exist_ok=True)
    df_clean.to_csv(PROCESSED_PATH, index=False)
    print(f"\nSaved cleaned data -> {PROCESSED_PATH}  (shape {df_clean.shape})")

    cleaning_report(df_raw, df_clean, dropped, miss_before, miss_after)


if __name__ == "__main__":
    main()
