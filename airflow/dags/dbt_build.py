import os
from datetime import datetime

from airflow import DAG
from airflow.providers.docker.operators.docker import DockerOperator

PROJECT_ROOT = os.environ.get(
    "PROJECT_ROOT",
    os.path.expanduser("/home/asilbek/e-commerce-data-platform"),
)

with DAG(
    dag_id="ecommerce_dbt_build",
    description="Build e-commerce analytics models with dbt",
    start_date=datetime(2026, 1, 1),
    schedule=None,
    catchup=False,
    tags=["dbt", "ecommerce"],
) as dag:

    dbt_build = DockerOperator(
        task_id="dbt_build",
        image="e-commerce-data-platform-dbt:latest",
        command=["build"],
        docker_url="unix://var/run/docker.sock",
        network_mode="ecommerce_shared",
        auto_remove="success",
                mounts=[
            {
                "Source": f"{PROJECT_ROOT}/dbt/ecommerce_analytics",
                "Target": "/usr/app",
                "Type": "bind",
            },
            {
                "Source": f"{PROJECT_ROOT}/dbt/profiles.yml",
                "Target": "/root/.dbt/profiles.yml",
                "Type": "bind",
                "ReadOnly": True,
            },
        ],
        working_dir="/usr/app",
        environment={
            "DBT_PROFILES_DIR": "/root/.dbt",
        },
        mount_tmp_dir=False,
    )

