"""Build the static figures embedded in the README.

Reuses the exact matplotlib/seaborn figures already executed in the notebooks
(decoded from the .ipynb outputs), and generates only the two charts that
exist solely as interactive plotly figures there:
  - readmission rate by age band
  - top-15 XGBoost feature importances (same train/test setup as 03_modeling)

Output: images/*.png

Run:  python src/make_figures.py
"""

import base64
import json
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import pandas as pd

PROJECT_ROOT = Path(__file__).resolve().parent.parent
NOTEBOOK_DIR = PROJECT_ROOT / "notebooks"
IMAGE_DIR = PROJECT_ROOT / "images"
DATA_PATH = PROJECT_ROOT / "data" / "processed" / "diabetes_clean.csv"

# (notebook, code-cell index among code cells, 1-based, output index, filename)
# Cell numbers were mapped from the executed notebooks. When a cell produces
# several PNGs, output index picks which one (0 = first).
EXTRACT = [
    ("01_eda", 4, 0, "target_distribution.png"),
    ("01_eda", 5, 0, "age_distribution.png"),
    ("01_eda", 7, 0, "prior_utilization.png"),
    ("01_eda", 12, 0, "prior_use_rates.png"),
    ("01_eda", 13, 0, "correlation_heatmap.png"),
    ("02_statistics", 3, 0, "discharge_rates.png"),
    ("03_modeling", 6, 0, "confusion_matrices.png"),
    ("03_modeling", 6, 1, "roc_curves.png"),
]


def extract_notebook_figures() -> None:
    IMAGE_DIR.mkdir(parents=True, exist_ok=True)
    for nb_name, cell_no, out_idx, filename in EXTRACT:
        nb = json.loads((NOTEBOOK_DIR / f"{nb_name}.ipynb").read_text())
        code_cells = [c for c in nb["cells"] if c["cell_type"] == "code"]
        cell = code_cells[cell_no - 1]
        pngs = [(output.get("data") or {}).get("image/png")
                for output in cell.get("outputs", [])]
        pngs = [p for p in pngs if p]
        png_b64 = pngs[out_idx]
        (IMAGE_DIR / filename).write_bytes(base64.b64decode(png_b64))
        print(f"extracted {nb_name} cell{cell_no}[{out_idx}] -> images/{filename}")


def readmission_by_age() -> None:
    df = pd.read_csv(DATA_PATH, keep_default_na=False)
    order = ["[0-10)", "[10-20)", "[20-30)", "[30-40)", "[40-50)",
             "[50-60)", "[60-70)", "[70-80)", "[80-90)", "[90-100)"]
    rates = df.groupby("age")["readmitted_30_days"].mean().mul(100).reindex(order)
    fig, ax = plt.subplots(figsize=(8, 4))
    rates.plot.bar(ax=ax, color="#c0392b")
    ax.set_title("30-day readmission rate by age band (%)")
    ax.set_xlabel("Age band")
    ax.set_ylabel("Readmission %")
    ax.tick_params(axis="x", rotation=30)
    for i, v in enumerate(rates.values):
        ax.text(i, v + 0.2, f"{v:.1f}", ha="center", fontsize=8)
    fig.tight_layout()
    fig.savefig(IMAGE_DIR / "readmission_by_age.png", dpi=120)
    plt.close(fig)
    print("generated images/readmission_by_age.png")


def feature_importance() -> None:
    from sklearn.compose import ColumnTransformer
    from sklearn.model_selection import train_test_split
    from sklearn.preprocessing import OneHotEncoder, StandardScaler
    from xgboost import XGBClassifier

    df = pd.read_csv(DATA_PATH, keep_default_na=False)
    drop = ["diag_1", "diag_2", "diag_3", "patient_nbr", "age_group"]
    X = df.drop(columns=drop + ["readmitted_30_days"])
    y = df["readmitted_30_days"]
    cat = X.select_dtypes(include=["object", "string"]).columns.tolist()
    num = [c for c in X.columns if c not in cat]
    pre = ColumnTransformer([("cat", OneHotEncoder(handle_unknown="ignore"), cat),
                             ("num", StandardScaler(), num)])
    X_train, _, y_train, _ = train_test_split(
        X, y, test_size=0.20, random_state=42, stratify=y)
    Xtr = pre.fit_transform(X_train)
    scale = (y_train == 0).sum() / (y_train == 1).sum()
    xgb = XGBClassifier(n_estimators=200, max_depth=5, learning_rate=0.1,
                        subsample=0.8, colsample_bytree=0.8,
                        scale_pos_weight=scale, random_state=42,
                        n_jobs=-1, eval_metric="logloss")
    xgb.fit(Xtr, y_train)

    imp = pd.DataFrame({"feature": pre.get_feature_names_out(),
                        "importance": xgb.feature_importances_})
    top = imp.sort_values("importance", ascending=False).head(15).sort_values("importance")
    fig, ax = plt.subplots(figsize=(8, 5.5))
    ax.barh(top["feature"], top["importance"], color="#2980b9")
    ax.set_title("Top 15 XGBoost features (prediction importance)")
    ax.set_xlabel("Importance")
    fig.tight_layout()
    fig.savefig(IMAGE_DIR / "feature_importance.png", dpi=120)
    plt.close(fig)
    print("generated images/feature_importance.png")


def main() -> None:
    extract_notebook_figures()
    readmission_by_age()
    feature_importance()


if __name__ == "__main__":
    main()
