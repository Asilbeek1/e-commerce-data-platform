from datetime import datetime

from airflow.providers.standard.operators.bash import BashOperator
from airflow.sdk import DAG

# dbt's virtualenv already has psycopg2, so the ingestion scripts run with it too
PYTHON = "/opt/dbt-venv/bin/python"
DBT = "/opt/dbt-venv/bin/dbt"
PROJECT_DIR = "/opt/airflow/dbt/ecommerce_analytics"
PROFILES_DIR = "/opt/airflow/dbt"

# logs/ and target/ go to /tmp so the worker never fights over file permissions
# with the `docker compose run dbt` container, which writes as root
COMMON_FLAGS = (
    f"--project-dir {PROJECT_DIR} "
    f"--profiles-dir {PROFILES_DIR} "
    "--log-path /tmp/dbt_logs"
)

with DAG(
    dag_id="ecommerce_dbt_build",
    description="Load the latest CSV files into raw, then build analytics models with dbt",
    start_date=datetime(2026, 1, 1),
    schedule="@daily",
    catchup=False,
    tags=["dbt", "ecommerce", "ingestion"],
) as dag:

    load_csv = BashOperator(
        task_id="load_csv",
        bash_command=f"{PYTHON} /opt/airflow/ingestion/load_all.py",
        env={"PGHOST": "ecommerce_postgres", "PGPORT": "5432"},
        append_env=True,
    )

    dbt_debug = BashOperator(
        task_id="dbt_debug",
        bash_command=f"{DBT} debug {COMMON_FLAGS}",
    )

    dbt_build = BashOperator(
        task_id="dbt_build",
        bash_command=f"{DBT} build {COMMON_FLAGS} --target-path /tmp/dbt_target",
    )

    load_csv >> dbt_debug >> dbt_build
