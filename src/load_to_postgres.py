"""Load the cleaned CSV into PostgreSQL.

Creates (or replaces) the `encounters` analytical table.
Connection defaults match the docker-compose / local setup in the README.

Env vars (optional): PGHOST, PGPORT, PGDATABASE, PGUSER, PGPASSWORD

Run:  python src/load_to_postgres.py
"""

import os
import pandas as pd
from pathlib import Path
from sqlalchemy import create_engine, text

PROJECT_ROOT = Path(__file__).resolve().parent.parent
CSV_PATH = PROJECT_ROOT / "data" / "processed" / "diabetes_clean.csv"


def get_engine():
    host = os.getenv("PGHOST", "localhost")
    port = os.getenv("PGPORT", "5432")
    db = os.getenv("PGDATABASE", "healthcare")
    user = os.getenv("PGUSER", "postgres")
    pwd = os.getenv("PGPASSWORD", "postgres")
    url = f"postgresql+psycopg2://{user}:{pwd}@{host}:{port}/{db}"
    return create_engine(url)


def main() -> None:
    df = pd.read_csv(CSV_PATH)
    print(f"Loaded CSV: {df.shape}")

    engine = get_engine()
    with engine.begin() as conn:
        conn.execute(text("DROP TABLE IF EXISTS encounters"))
    df.to_sql("encounters", engine, index=False, chunksize=5000)
    print(f"Loaded {len(df)} rows into table 'encounters'.")

    with engine.connect() as conn:
        n = conn.execute(text("SELECT COUNT(*) FROM encounters")).scalar()
        rate = conn.execute(
            text("SELECT ROUND(AVG(readmitted_30_days)::numeric, 4) FROM encounters")
        ).scalar()
        print(f"Verify -> rows: {n}, readmission rate: {rate}")


if __name__ == "__main__":
    main()
