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
```

Then, on a Mac, **double-click `Start Learning Week.app`** in the Finder. The
control panel opens in your browser. That is the whole setup.

Everything else can be done from the panel: paste your Datadog keys, confirm
they work, and start or stop the day you are working on. Leave the Terminal
window that appears open while you use the panel, and press Ctrl+C in it when
you are finished.

If you would rather stay in the terminal, the sections below cover the same
ground with the scripts directly. The panel and the scripts do the same work,
so it is fine to mix them.

## The Control Panel

Three ways in, all equivalent:

| | |
|---|---|
| `Start Learning Week.app` | double-click in the Finder, macOS |
| `start-ui.command` | double-click in the Finder, macOS |
| `./start-ui.sh` | any terminal, macOS or Linux |

Keep the app inside the cloned folder. It looks for `lab-ui/` next to itself and
will tell you if it has been moved somewhere else.

### If macOS says it cannot verify the app

You will see **"Start Learning Week" Not Opened**, offering only *Move to Trash*
and *Done*. Nothing is wrong with the file. The app is not signed with an Apple
Developer certificate, and macOS blocks unsigned apps that arrived as a download,
a zip, or an AirDrop. Do not move it to the trash.

The fastest fix, which also makes the double-click work from then on, is to start
it from a terminal once. Terminal is never blocked:

```bash
cd <the folder you unzipped>
./start-ui.sh
```

That clears the quarantine flag on this folder for you. Afterwards the app opens
normally on a double-click.

If you would rather do it by hand, either of these works:

```bash
xattr -dr com.apple.quarantine "<the folder you unzipped>"
```

or open **System Settings**, go to **Privacy & Security**, scroll to the bottom,
and choose **Open Anyway** next to the app. On macOS 15 and newer this is the
only place that option appears; Control-clicking the app no longer offers it.

You will not hit this at all if you got the folder with `git clone`, because git
does not set the quarantine flag.

All three run a small local server on `127.0.0.1:8765` and open
`http://127.0.0.1:8765`. Nothing is exposed outside your machine. Python 3.8 or
newer is the only requirement, with no packages to install.

If the port is already in use the panel says so and tells you what to do. To
pick another one: `LAB_UI_PORT=8766 ./start-ui.sh`.

What it gives you:

- a credentials form that writes your keys to `.env`, plus a **Test connection**
  button that asks Datadog whether they actually work before you spend ten
  minutes on a setup run
- a check of Docker and your keys, with the specific fix when something is missing
- Start, Check, Stop and Clean for each day, with live output and a real progress
  bar driven by the setup script's own steps
- a status tile per day so you can see what is running
- **Destroy All** for the end of the week

Only one day runs at a time. The whole week does not fit in memory at once, so
starting a second day asks you to stop the first.

## First-Time Setup

The control panel handles this for you. To do it by hand instead, copy the
example environment file and add your own Datadog keys:

```bash
cp .env.example .env
```

Set:

```bash
DD_API_KEY=...
DD_APP_KEY=...
DD_SITE=datadoghq.com
```

Each participant should use their own Datadog org and their own API/application
keys. The application key needs permission to read and write monitors. `.env` is
listed in `.gitignore`, so your keys are never committed.

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
