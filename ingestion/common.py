
import csv
import os
import re
from pathlib import Path

import psycopg2
from psycopg2 import sql


PROJECT_ROOT = Path(__file__).resolve().parent.parent
DATA_DIR = PROJECT_ROOT / "data"



TABLES = {
    "customers": {
        "primary_key": "customer_id",
        "columns": [
            "customer_id",
            "full_name",
            "email",
            "region",
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
            "cost_price",
        ],
    },
    "orders": {
        "primary_key": "order_id",
        "columns": [
            "order_id",
            "customer_id",
            "amount",
            "status",
            "channel",
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

# Load parent records before dependent records.
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
        host=os.getenv(
            "PGHOST",
            os.getenv("POSTGRES_HOST", "localhost"),
        ),
        port=os.getenv(
            "PGPORT",
            os.getenv("POSTGRES_PORT", "5432"),
        ),
        dbname=os.getenv(
            "PGDATABASE",
            os.getenv("POSTGRES_DB", "ecommerce"),
        ),
        user=os.getenv(
            "PGUSER",
            os.getenv("POSTGRES_USER", "analytics_user"),
        ),
        password=os.getenv(
            "PGPASSWORD",
            os.getenv("POSTGRES_PASSWORD", "dev_only_change_me"),
        ),
    )


def get_csv_files(table_name):
    """
    Return all numbered CSV files in ascending order.

    Example:
        orders_001.csv
        orders_002.csv
        orders_010.csv
    """

    if table_name not in TABLES:
        raise ValueError(f"Unknown table: {table_name}")

    folder = DATA_DIR / table_name

    if not folder.exists():
        raise FileNotFoundError(
            f"Data directory does not exist: {folder}"
        )

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
            f"No numbered CSV files found in {folder}"
        )

    # Sort numerically, not alphabetically.
    candidates.sort(key=lambda item: item[0])

    return [path for _, path in candidates]


def read_csv(file_path, expected_columns):
    """Read a CSV and validate its required columns."""

    with file_path.open(
        "r",
        encoding="utf-8-sig",
        newline="",
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
            cleaned_row = {}

            for column in expected_columns:
                value = row[column]

                if value is not None:
                    value = value.strip()

                cleaned_row[column] = (
                    None if value == "" else value
                )

            rows.append(cleaned_row)

        return rows


def upsert_rows(conn, table_name, rows):
    """
    Insert new records and update existing records
    when their primary keys already exist.
    """

    if not rows:
        return 0

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
            sql.Identifier(column)
            for column in columns
        ),

        sql.SQL(", ").join(
            sql.Placeholder()
            for _ in columns
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

    values = [
        tuple(row[column] for column in columns)
        for row in rows
    ]

    with conn.cursor() as cur:
        cur.executemany(insert_query, values)

    return len(rows)


def load_table(table_name, conn=None):
    """
    Load every numbered CSV for one table.

    If a connection is provided, reuse it.
    Otherwise, create a separate connection.
    """

    if table_name not in TABLES:
        raise ValueError(f"Unknown table: {table_name}")

    if conn is None:
        with get_connection() as connection:
            return load_table(table_name, connection)

    files = get_csv_files(table_name)

    total_rows = 0

    print(f"\n[{table_name}] Found {len(files)} CSV file(s)")

    for file_path in files:
        print(f"[{table_name}] Processing {file_path.name}")

        rows = read_csv(
            file_path,
            TABLES[table_name]["columns"],
        )

        loaded = upsert_rows(
            conn,
            table_name,
            rows,
        )

        total_rows += loaded

        print(
            f"[{table_name}] Processed {loaded} rows "
            f"from {file_path.name}"
        )

    print(
        f"[{table_name}] Total processed: {total_rows} rows"
    )

    return total_rows


def load_all():
    """
    Load all six tables in dependency order.

    All tables share one transaction:
    if any table fails, all changes are rolled back.
    """

    total_rows = 0

    with get_connection() as conn:

        for table_name in LOAD_ORDER:
            total_rows += load_table(
                table_name,
                conn,
            )

    print("\nIngestion completed successfully.")
    print(f"Total rows processed: {total_rows}")

    return total_rows


if __name__ == "__main__":
    load_all()
    