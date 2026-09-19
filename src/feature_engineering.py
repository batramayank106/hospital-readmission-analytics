"""Feature engineering: small set of explainable features.

No data leakage: every feature is known at/before discharge. The target
(readmitted_30_days) is never used to build a feature.

Features:
  age_group                 Copy of the 10-year age band (ordered category).
                            Useful because readmission rises with age.
  diagnosis_count_band      Low (1-3) / Medium (4-6) / High (7+).
                            Sicker patients (more diagnoses) return more often.
  medication_count_band     Low (1-10) / Medium (11-20) / High (21+).
                            Polypharmacy signals complex cases.
  prior_inpatient_visit_band 0 / 1 / 2+ inpatient visits in the prior year.
                            Past hospital use predicts future use.
  length_of_stay_band       Short (1-2 days) / Medium (3-4) / Long (5+ days).
                            Very short or long stays behave differently.
  high_utilization_flag     1 when total prior-year visits
                            (outpatient + emergency + inpatient) >= 3.
                            Flags repeat users of the hospital system.

Run:  python src/feature_engineering.py   (adds features to the cleaned CSV)
"""

import pandas as pd
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
PROCESSED_PATH = PROJECT_ROOT / "data" / "processed" / "diabetes_clean.csv"


def add_features(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()

    # Age band, kept as ordered category so plots/models respect the order.
    age_order = ["[0-10)", "[10-20)", "[20-30)", "[30-40)", "[40-50)",
                 "[50-60)", "[60-70)", "[70-80)", "[80-90)", "[90-100)"]
    df["age_group"] = pd.Categorical(df["age"], categories=age_order, ordered=True)

    # Number of diagnoses -> Low / Medium / High.
    df["diagnosis_count_band"] = pd.cut(
        df["number_diagnoses"],
        bins=[0, 3, 6, 100],
        labels=["Low (1-3)", "Medium (4-6)", "High (7+)"],
    )

    # Number of medications -> Low / Medium / High.
    df["medication_count_band"] = pd.cut(
        df["num_medications"],
        bins=[0, 10, 20, 100],
        labels=["Low (1-10)", "Medium (11-20)", "High (21+)"],
    )

    # Prior inpatient visits -> 0 / 1 / 2+.
    df["prior_inpatient_visit_band"] = pd.cut(
        df["number_inpatient"],
        bins=[-1, 0, 1, 100],
        labels=["0", "1", "2+"],
    )

    # Length of stay -> Short / Medium / Long.
    df["length_of_stay_band"] = pd.cut(
        df["time_in_hospital"],
        bins=[0, 2, 4, 100],
        labels=["Short (1-2)", "Medium (3-4)", "Long (5+)"],
    )

    # High-utilization flag: 3+ total prior-year visits.
    prior_total = df["number_outpatient"] + df["number_emergency"] + df["number_inpatient"]
    df["high_utilization_flag"] = (prior_total >= 3).astype(int)

    return df


def main() -> None:
    df = pd.read_csv(PROCESSED_PATH)
    df = add_features(df)
    df.to_csv(PROCESSED_PATH, index=False)
    print(f"Features added, saved -> {PROCESSED_PATH}  (shape {df.shape})")
    print("New columns: age_group, diagnosis_count_band, medication_count_band, "
          "prior_inpatient_visit_band, length_of_stay_band, high_utilization_flag")


if __name__ == "__main__":
    main()
