# Metrics and Monitors Learning Week - Student Runbook

Use one day at a time. Each student should use their own Datadog org and their
own API / application keys.

## First-Time Setup

```bash
cp .env.example .env
```

Edit `.env` and set:

```bash
DD_API_KEY=...
DD_APP_KEY=...
DD_SITE=datadoghq.com
```

## Hard Mode Learning Rules

This Learning Week is designed as troubleshooting practice, not as a query-copying exercise.

- Run only the setup for the current day so the next scenarios are not spoiled.
- Use `check_dayX` to validate the environment, not to validate the answer.
- Keep an evidence log for every mission: symptom, query tested, hypothesis, rejected alternative, chosen fix, and trade-off.
- Use the `LAB.md` files as the source of truth for each day.
- Ask for a facilitator hint only after 15 minutes or after documenting one failed hypothesis.
- For every monitor change, be ready to explain why it catches the real issue without adding unnecessary noise.

## Daily Flow

At the start of each class, run that day's setup:

```bash
./setup_day1_apm.sh
./setup_day2_containers.sh
./setup_day3_dbm.sh
./setup_day4_logs.sh
./setup_day5_dynamic.sh
```

Then validate:

```bash
./check_day1_apm.sh
./check_day2_containers.sh
./check_day3_dbm.sh
./check_day4_logs.sh
./check_day5_dynamic.sh
```

At the end of the day, stop only that day's local services:

```bash
./stop_day1_apm.sh
./stop_day2_containers.sh
./stop_day3_dbm.sh
./stop_day4_logs.sh
./stop_day5_dynamic.sh
```

`stop_dayX` keeps Datadog monitors and historical data. Use this during the week.

## Cleanup

Use cleanup only if a day needs to be rebuilt or at the end of the week:

```bash
./cleanup_day1_apm.sh
./cleanup_day2_containers.sh
./cleanup_day3_dbm.sh
./cleanup_day4_logs.sh
./cleanup_day5_dynamic.sh
```

`cleanup_dayX` removes local resources and deletes that day's monitors.

`reset.sh` removes all local resources for the full week. Use it only when you want to rebuild everything from scratch.
