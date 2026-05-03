# Metrics and Monitors Learning Week

Five-day troubleshooting curriculum for Datadog TSE practice. The goal is to build investigation habits for Metrics and Monitors cases: form a hypothesis, prove it with evidence, compare alternatives, tune noise, and explain the result clearly.

## What Is Included

- Day 1: APM trace metrics, metric types, rollups, and monitor shape
- Day 2: Kubernetes/container metrics and ownership dimensions
- Day 3: Database Monitoring signals and noisy DB monitor patterns
- Day 4: Log monitors, facets, routing, and alert-message quality
- Day 5: Dynamic custom metrics challenge with ecommerce and IoT scenarios

## Required Local Tools

- Docker Desktop
- `kubectl`
- `minikube`
- `helm`
- `curl`
- `jq`
- Python 3

## After Cloning

```bash
git clone <repository-url>
cd <repository-directory>
cp .env.example .env
```

Add your own Datadog keys to `.env`, then run only the setup script for the current day.

## First-Time Setup

Copy the example environment file and add your own Datadog keys:

```bash
cp .env.example .env
```

Set:

```bash
DD_API_KEY=...
DD_APP_KEY=...
DD_SITE=datadoghq.com
```

Each participant should use their own Datadog org and their own API/application keys.

## Daily Setup

Run only the current day. This keeps later scenarios fresh.

```bash
./setup_day1_apm.sh
./setup_day2_containers.sh
./setup_day3_dbm.sh
./setup_day4_logs.sh
./setup_day5_dynamic.sh
```

Validate the environment:

```bash
./check_day1_apm.sh
./check_day2_containers.sh
./check_day3_dbm.sh
./check_day4_logs.sh
./check_day5_dynamic.sh
```

Stop a day without deleting monitor history:

```bash
./stop_day1_apm.sh
./stop_day2_containers.sh
./stop_day3_dbm.sh
./stop_day4_logs.sh
./stop_day5_dynamic.sh
```

Clean up a day when you need to rebuild it:

```bash
./cleanup_day1_apm.sh
./cleanup_day2_containers.sh
./cleanup_day3_dbm.sh
./cleanup_day4_logs.sh
./cleanup_day5_dynamic.sh
```

## How To Work

- the starting symptom
- the tested query or screen
- the hypothesis
- one rejected alternative
- two possible fixes
- the chosen trade-off
- the customer-ready explanation

## GitHub Safety

Do not commit `.env` files, diagnostic dumps, local logs, temporary files, slides, or authoring artifacts. The repository `.gitignore` excludes those by default.
