FROM apache/airflow:3.3.2

# dbt lives in its own virtualenv so its dependencies don't clash with Airflow's
USER root
RUN python -m venv /opt/dbt-venv \
    && /opt/dbt-venv/bin/pip install --no-cache-dir dbt-core==1.9.1 dbt-postgres==1.9.1 \
    && chown -R airflow:0 /opt/dbt-venv

USER airflow
