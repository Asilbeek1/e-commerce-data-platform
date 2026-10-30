# E-commerce Data Platform

Учебная платформа данных для интернет-магазина: сырые данные в PostgreSQL, обработка через dbt, визуализация в DataLens. Всё запускается локально в Docker.

```
CSV (data/)  →  PostgreSQL (raw)  →  dbt (staging → marts)  →  DataLens (дашборд)
        └──────── Airflow: загрузка + dbt раз в день ────────┘
```

## Структура проекта

```
.
├── docker-compose.yml              # PostgreSQL + контейнер dbt
├── docker/
│   ├── postgres/init/
│   │   └── 01_init.sql             # схема raw и 6 таблиц
│   └── dbt/Dockerfile              # образ с dbt-postgres 1.9.1
├── data/                           # исходные CSV: <таблица>/<таблица>_NNN.csv
├── ingestion/                      # загрузка последнего CSV каждой таблицы в raw (upsert)
├── dbt/
│   ├── profiles.yml                # подключение dbt к базе
│   └── ecommerce_analytics/
│       ├── dbt_project.yml
│       └── models/
│           ├── staging/            # очистка сырых данных (views)
│           └── marts/              # витрины и fct_orders (tables)
│       └── tests/                  # проверки данных (singular tests)
├── datalens/
│   └── ecommerce_workbook.json     # экспорт воркбука DataLens
└── airflow/
    ├── docker-compose.yaml         # Airflow 3.3 (CeleryExecutor)
    ├── Dockerfile                  # образ Airflow + dbt
    ├── .env.example                # шаблон настроек (UID, порт)
    └── dags/dbt_build.py           # DAG: load_csv → dbt debug → dbt build
```

## Модель данных

**raw** — исходные таблицы: `orders`, `customers`, `products`, `order_items`, `payments`, `refunds`.

**staging** (схема `analytics`, представления):

| Модель | Что делает |
|---|---|
| `stg_orders` | только завершённые заказы (`status = 'completed'`, `amount > 0`) |
| `stg_customers` | чистит имя, приводит email к нижнему регистру |
| `stg_products` | чистит название и категорию |
| `stg_orders_items` | считает сумму строки `quantity * unit_price` |
| `stg_payments` | платежи с датой оплаты |
| `stg_refunds` | возвраты с датой возврата |

**marts** (схема `analytics`, таблицы):

| Витрина | Содержимое |
|---|---|
| `mart_daily_revenue` | по дням: заказы, выручка, средний чек, возвраты, чистая выручка |
| `mart_sales_by_category` | по дням и категориям: заказы, проданные штуки, выручка |
| `mart_customers` | по клиентам: число заказов, сумма покупок, первая и последняя покупка |
| `fct_orders` | факт-таблица: одна строка на заказ — позиции, оплата, возвраты, чистая сумма |

На модели настроены тесты `unique`, `not_null` и `relationships` для ключевых полей. В папке `tests/` лежат проверки данных: возврат не больше суммы заказа, сумма заказа равна сумме его позиций.

## Требования

- Docker Desktop (на Windows — с включённой WSL integration для Ubuntu)
- Git
- Свободные порты: `5432` (PostgreSQL), `8080` (DataLens), `8081` (Airflow)

На Windows все команды ниже выполняются в терминале **Ubuntu (WSL)**, а не в PowerShell.

## Запуск

### 1. База и dbt

```bash
git clone git@github.com:Asilbeek1/e-commerce-data-platform.git
cd e-commerce-data-platform

docker network create ecommerce_shared   # один раз: общая сеть для базы, dbt и Airflow
docker compose up -d

# загрузка CSV из data/ в схему raw (Python ставить не нужно — скрипт запускается в контейнере)
docker run --rm --network ecommerce_shared -v "$PWD":/app -w /app \
  -e PGHOST=ecommerce_postgres python:3.11-slim \
  sh -c "pip install -q -r ingestion/requirements.txt && python ingestion/load_all.py"

docker compose run --rm dbt build
```

Проверка: загрузка заканчивается строкой `All ingestion tasks completed successfully.`, `dbt build` — строкой `Done. PASS=44 WARN=0 ERROR=0`.

```bash
docker exec -it ecommerce_postgres psql -U analytics_user -d ecommerce -c "select count(*) from raw.orders;"
```

Ожидается `30`.

Загрузку можно запускать повторно: строки обновляются по первичному ключу, дубликатов не будет. Новые данные кладутся следующим файлом с бо́льшим номером (`orders_002.csv` и т. д.) — загружается только последний файл каждой таблицы.

> Скрипты из `docker/postgres/init/` выполняются только при первом создании базы. Чтобы пересоздать базу с нуля: `docker compose down -v && docker compose up -d`.

### 2. DataLens

```bash
cd ..
git clone https://github.com/datalens-tech/datalens.git
cd datalens
HC=1 docker compose up -d
```

Подключите базу проекта к сети DataLens:

```bash
docker network connect --alias ecommerce-postgres datalens_default ecommerce_postgres
```

Откройте http://localhost:8080 (логин `admin`, пароль `admin`).

### 3. Дашборд

**Вариант А — импорт готового воркбука.** Collections and workbooks → Create → Import workbook → файл `datalens/ecommerce_workbook.json`. После импорта откройте подключение `e-commerce` и заново введите пароль (пароли не экспортируются).

**Вариант Б — подключение вручную.** Создайте воркбук → Create → Connection → PostgreSQL:

| Поле | Значение |
|---|---|
| Hostname | `ecommerce-postgres` |
| Port | `5432` |
| Path to database | `ecommerce` |
| Username | `analytics_user` |
| Password | `dev_only_change_me` |

Датасеты создаются из таблиц схемы `analytics` (`mart_*`).

## Ежедневный запуск

После перезагрузки компьютера: запустить Docker Desktop, затем в Ubuntu:

```bash
cd ~/e-commerce-data-platform && docker compose up -d
cd ~/datalens && docker compose up -d
docker network connect --alias ecommerce-postgres datalens_default ecommerce_postgres
cd ~/e-commerce-data-platform/airflow && docker compose up -d
```

## Airflow

Airflow раз в день загружает свежие CSV и пересобирает витрины, без ручных команд. DAG `ecommerce_dbt_build` состоит из трёх задач: `load_csv` (последний CSV каждой таблицы → схема `raw`) → `dbt_debug` (проверка подключения) → `dbt_build` (модели и тесты). Папки `ingestion/` и `data/` подключены к Airflow только на чтение. dbt установлен прямо в образ Airflow и подключается к базе `ecommerce_postgres` через общую сеть `ecommerce_shared`.

Нужно не меньше 4 ГБ свободной памяти для Docker.

**Первый запуск** (база проекта уже должна быть запущена):

```bash
cd airflow
cp .env.example .env
sed -i "s/AIRFLOW_UID=.*/AIRFLOW_UID=$(id -u)/" .env
docker compose up -d --build
```

Первая сборка образа занимает 5–10 минут. Затем откройте http://localhost:8081 (логин `airflow`, пароль `airflow`), найдите DAG `ecommerce_dbt_build`, включите его переключателем и нажмите ▶ (Trigger), чтобы запустить сразу.

Порт по умолчанию — `8081`, потому что `8080` занят DataLens. Изменить можно в `airflow/.env` (`AIRFLOW_PORT`).

## Безопасность

Все пароли в репозитории (`dev_only_change_me`, `admin/admin`, `airflow/airflow`) — только для локальной разработки. 
