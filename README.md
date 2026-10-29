# E-commerce Data Platform

Учебная платформа данных для интернет-магазина: сырые данные в PostgreSQL, обработка через dbt, визуализация в DataLens. Всё запускается локально в Docker.

```
PostgreSQL (raw)  →  dbt (staging → marts)  →  DataLens (дашборд)
                          ↑
                   Airflow (в разработке)
```

## Структура проекта

```
.
├── docker-compose.yml              # PostgreSQL + контейнер dbt
├── docker/
│   ├── postgres/init/
│   │   ├── 01_init.sql             # схема raw и 6 таблиц
│   │   └── 02_seed.sql             # тестовые данные
│   └── dbt/Dockerfile              # образ с dbt-postgres 1.9.1
├── dbt/
│   ├── profiles.yml                # подключение dbt к базе
│   └── ecommerce_analytics/
│       ├── dbt_project.yml
│       └── models/
│           ├── staging/            # очистка сырых данных (views)
│           └── marts/              # витрины для дашборда (tables)
├── datalens/
│   └── ecommerce_workbook.json     # экспорт воркбука DataLens
└── airflow/                        # оркестрация dbt (в разработке)
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

На модели настроены тесты `unique` и `not_null` для ключевых полей.

## Требования

- Docker Desktop (на Windows — с включённой WSL integration для Ubuntu)
- Git
- Свободные порты: `5432` (PostgreSQL), `8080` (DataLens)

На Windows все команды ниже выполняются в терминале **Ubuntu (WSL)**, а не в PowerShell.

## Запуск

### 1. База и dbt

```bash
git clone git@github.com:Asilbeek1/e-commerce-data-platform.git
cd e-commerce-data-platform

docker compose up -d
docker compose run --rm dbt build
```

Проверка: `dbt build` должен закончиться строкой `Done. PASS=27 WARN=0 ERROR=0`.

```bash
docker exec -it ecommerce_postgres psql -U analytics_user -d ecommerce -c "select count(*) from raw.orders;"
```

Ожидается `2000`.

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
```

Сообщение `already exists` у последней команды — это нормально.

## Частые проблемы

| Симптом | Причина и решение |
|---|---|
| `docker: command not found` в Ubuntu | Docker Desktop не запущен или выключена WSL integration (Settings → Resources → WSL integration → Ubuntu) |
| `localhost refused to connect` | контейнеры не запущены — `docker compose up -d` в обеих папках |
| «Что-то пошло не так» в DataLens сразу после старта | сервис `us` стартовал раньше своей базы: `cd ~/datalens && docker compose restart us` |
| `Unable to parse host: ecommerce_postgres` | DataLens не принимает `_` в имени хоста — используйте алиас `ecommerce-postgres` |
| `password authentication failed` | браузер подставил сохранённый `admin` в поля логина и пароля — введите данные вручную |
| `HC=1 is not recognized` | команда запущена в PowerShell — откройте Ubuntu |

## Airflow (в разработке)

В папке `airflow/` лежит конфигурация Airflow 3.3 (CeleryExecutor) и DAG `dbt_build.py` для запуска dbt по расписанию. Перед запуском вместе с DataLens нужно сменить порт веб-интерфейса Airflow с `8080` на свободный (например, `8081:8080` в `airflow/docker-compose.yaml`), иначе он конфликтует с DataLens.

## Безопасность

Все пароли в репозитории (`dev_only_change_me`, `admin/admin`, `airflow/airflow`) — только для локальной разработки. Тестовые данные сгенерированы и не содержат реальных клиентов.
