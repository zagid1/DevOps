# Osm

Демонстрационный репозиторий к лабораторной работе №20 «Интеграция Git Hooks
с CI/CD».

FastAPI-сервис транскрипции аудио (GigaAM) используется как носитель кода:
в нём нет ничего необычного, вся ценность — в контуре проверок вокруг него.

## Что внутри

| Слой | Где | Что делает |
|---|---|---|
| Локальный | `.githooks/` | `pre-commit` (TODO), `pre-push` (проверки + тесты), `commit-msg` (трейлер-аттестация) |
| Серверный | `Jenkinsfile` | 5 стадий: fast-checks, unit, integration, bandit, load |
| Агрегация | `scripts/aggregate_report.py` | Сводит трейлеры хуков и коды стадий в `reports/ci-report.json` |
| Дублирующий | `.github/workflows/ci.yml` | GitHub Actions прогоняет быстрый контур |

Архитектура, разделение проверок и обоснование выбора — в
[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

## Установка хуков

```bash
git config core.hooksPath .githooks
```

## Локальный запуск

```bash
bash scripts/checks.sh               # синтаксис + ruff + TODO
bash scripts/integration_test.sh     # реальный сервер на :8101
bash scripts/load_test.sh            # нагрузка на :8102
python scripts/aggregate_report.py   # единый отчёт в reports/
```

## Запуск сервиса

```bash
python server.py                     # http://127.0.0.1:8000/docs
```

Полезные переменные окружения:

| Переменная | По умолчанию | Назначение |
|---|---|---|
| `PORT` | `8000` | Порт HTTP-сервера |
| `LOG_DIR` | `./logs` | Каталог для `voiceapi.log` (JSON, для Logstash) |
| `VOICEAPI_SKIP_MODEL_LOAD` | не задана | `1` — поднять API без загрузки весов модели |

## API

| Метод | Путь | Назначение |
|---|---|---|
| `GET` | `/health` | Живость сервиса |
| `GET` | `/ready` | `503`, пока модель не загружена |
| `GET` | `/v1/models` | Список доступных моделей |
| `POST` | `/v1/audio/transcriptions` | Транскрипция аудиофайла |

## Зависимости

```bash
python -m pip install -r requirements.txt -r requirements-dev.txt
```
