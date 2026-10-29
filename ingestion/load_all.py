
from common import LOAD_ORDER, load_table


def main():
    for table_name in LOAD_ORDER:
        print(f"\n{'=' * 40}")
        print(f"Loading table: {table_name}")
        print(f"{'=' * 40}")

        load_table(table_name)

    print("\nAll ingestion tasks completed successfully.")


if __name__ == "__main__":
    main()

