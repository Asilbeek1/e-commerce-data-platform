
import csv
import os
import re
from pathlib import Path

import psycopg2
from psycopg2 import sql


PROJECT_ROOT = Path(__file__).resolve().parent.parent
DATA_DIR = PROJECT_ROOT / "data"

# Each table's primary key and CSV/database columns.
TABLES = {
    "customers": {
        "primary_key": "customer_id",
        "columns": [
            "customer_id",
            "full_name",
            "email",
            "registered_at",
        ],
    },
    "products": {
        "primary_key": "product_id",
        "columns": [
            "product_id",
            "product_name",
            "category",
            "list_price",
        ],
    },
    "orders": {
        "primary_key": "order_id",
        "columns": [
            "order_id",
            "customer_id",
            "amount",
            "status",
            "created_at",
        ],
    },
    "order_items": {
        "primary_key": "order_item_id",
        "columns": [
            "order_item_id",
            "order_id",
            "product_id",
            "quantity",
            "unit_price",
        ],
    },
    "payments": {
        "primary_key": "payment_id",
        "columns": [
            "payment_id",
            "order_id",
            "amount",
            "payment_method",
            "status",
            "paid_at",
        ],
    },
    "refunds": {
        "primary_key": "refund_id",
        "columns": [
            "refund_id",
            "order_id",
            "amount",
            "status",
            "refunded_at",
        ],
    },
}

# Load parent records before records that reference them.
LOAD_ORDER = [
    "customers",
    "products",
    "orders",
    "order_items",
    "payments",
    "refunds",
]


def get_connection():
    """Connect to the existing ecommerce PostgreSQL database."""
    return psycopg2.connect(
        host=os.getenv("PGHOST", "localhost"),
        port=os.getenv("PGPORT", "5432"),
        dbname=os.getenv("POSTGRES_DB", "ecommerce"),
        user=os.getenv("POSTGRES_USER", "analytics_user"),
        password=os.getenv("POSTGRES_PASSWORD", "dev_only_change_me"),
    )


def get_latest_csv(table_name):
    """
    Find the CSV with the highest numeric suffix.

    Example:
        orders_001.csv
        orders_002.csv
        orders_010.csv  <- selected
    """
    folder = DATA_DIR / table_name
    pattern = re.compile(
        rf"^{re.escape(table_name)}_(\d+)\.csv$"
    )

    candidates = []

    for path in folder.glob(f"{table_name}_*.csv"):
        match = pattern.match(path.name)

        if match:
            sequence = int(match.group(1))
            candidates.append((sequence, path))

    if not candidates:
        raise FileNotFoundError(
            f"No matching CSV files found in {folder}"
        )

    return max(candidates, key=lambda item: item[0])[1]


def already_processed(conn, table_name, file_name):
    """Return True if this file was previously loaded successfully."""
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT 1
            FROM raw.ingestion_file_log
            WHERE table_name = %s
              AND file_name = %s
              AND status = 'success'
            """,
            (table_name, file_name),
        )

        return cur.fetchone() is not None


def read_csv(file_path, expected_columns):
    """Read a CSV and verify that its required columns are present."""
    with file_path.open(
        "r", encoding="utf-8-sig", newline=""
    ) as file:
        reader = csv.DictReader(file)

        if reader.fieldnames is None:
            raise ValueError(f"CSV is empty: {file_path}")

        missing = set(expected_columns) - set(reader.fieldnames)

        if missing:
            raise ValueError(
                f"{file_path.name} is missing columns: "
                f"{sorted(missing)}"
            )

        rows = []

        for row in reader:
            # Ignore extra columns; use only the target table columns.
            cleaned_row = {
                column: (
                    row[column].strip()
                    if row[column] is not None
                    else None
                )
                for column in expected_columns
            }

            # Interpret empty CSV cells as SQL NULL.
            cleaned_row = {
                column: (
                    None if value == "" else value
                )
                for column, value in cleaned_row.items()
            }

            rows.append(cleaned_row)

        return rows


def mark_processing(table_name, file_name):
    """Record that ingestion of this file has started."""
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO raw.ingestion_file_log (
                    table_name,
                    file_name,
                    status,
                    rows_loaded,
                    processed_at
                )
                VALUES (%s, %s, 'processing', NULL, NULL)
                ON CONFLICT (table_name, file_name)
                DO UPDATE SET
                    status = 'processing',
                    rows_loaded = NULL,
                    processed_at = NULL
                """,
                (table_name, file_name),
            )


def upsert_rows(conn, table_name, rows):
    """
    Insert new rows and update existing rows on primary-key conflicts.
    """
    if not rows:
        return

    config = TABLES[table_name]
    columns = config["columns"]
    primary_key = config["primary_key"]

    update_columns = [
        column
        for column in columns
        if column != primary_key
    ]

    insert_query = sql.SQL(
        """
        INSERT INTO {}.{} ({})
        VALUES ({})
        ON CONFLICT ({})
        DO UPDATE SET {}
        """
    ).format(
        sql.Identifier("raw"),
        sql.Identifier(table_name),
        sql.SQL(", ").join(
            sql.Identifier(column) for column in columns
        ),
        sql.SQL(", ").join(
            sql.Placeholder() for _ in columns
        ),
        sql.Identifier(primary_key),
        sql.SQL(", ").join(
            sql.SQL("{} = EXCLUDED.{}").format(
                sql.Identifier(column),
                sql.Identifier(column),
            )
            for column in update_columns
        ),
    )

    with conn.cursor() as cur:
        for row in rows:
            values = tuple(row[column] for column in columns)
            cur.execute(insert_query, values)



def load_table(table_name):
    """Load the latest CSV for one table using UPSERT."""
    if table_name not in TABLES:
        raise ValueError(f"Unknown table: {table_name}")

    file_path = get_latest_csv(table_name)

    print(f"\n[{table_name}] Latest CSV: {file_path.name}")

    rows = read_csv(file_path, TABLES[table_name]["columns"])

    # Insert new records or update existing records.
    with get_connection() as conn:
        upsert_rows(conn, table_name, rows)

    print(
        f"[{table_name}] Successfully processed "
        f"{len(rows)} rows from {file_path.name}"
    )

