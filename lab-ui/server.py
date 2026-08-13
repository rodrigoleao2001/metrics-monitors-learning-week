#!/usr/bin/env python3
"""
Monitors and Metrics Learning Week: lab control panel.

A tiny local control panel for starting, checking and stopping the Learning Week
labs. Python standard library only, no pip install, no network listener beyond
localhost.

Run it from the root of the Learning Week folder:

    python3 lab-ui/server.py

then open http://127.0.0.1:8765 in a browser.

Design notes for whoever maintains this:

  One job at a time. Every lifecycle script mutates Docker or minikube, so the
  server holds a single global job slot and refuses a second concurrent run.

  No shell string interpolation. The browser sends an action name and a day
  number, both of which are looked up in a fixed table below. Nothing the
  browser sends ever reaches a shell.

  The setup scripts source shared/bootstrap.sh, which prompts on stdin when
  Docker is missing or when the .env has no keys. Those prompts would hang a
  headless run, so /api/state reports a preflight verdict and the UI blocks the
  start buttons until it passes. stdin is also closed as a backstop.
"""

import json
import os
import re
import shutil
import subprocess
import sys
import threading
import time
import urllib.error
import urllib.request
import webbrowser
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
UI_DIR = os.path.join(ROOT, "lab-ui")
HOST = "127.0.0.1"
PORT = int(os.environ.get("LAB_UI_PORT", "8765"))

MINIKUBE_PROFILE = "learning-week-k8s"

DAYS = {
    1: {
        "title": "APM",
        "subtitle": "The Latency Lie",
        "kind": "compose",
        "compose": ["day1-apm/docker-compose.yml"],
        "tag": "learning-week:day1-apm",
        "weight": "light",
    },
    2: {
        "title": "Containers",
        "subtitle": "The Kubernetes Resource Crisis",
        "kind": "minikube",
        "compose": [],
        "tag": "learning-week:day2-containers",
        "weight": "heavy",
    },
    3: {
        "title": "DBM",
        "subtitle": "The Silent Database Killer",
        "kind": "compose",
        "compose": ["day3-dbm/docker-compose.yml"],
        "tag": "learning-week:day3-dbm",
        "weight": "light",
    },
    4: {
        "title": "Logs",
        "subtitle": "The Log Flood",
        "kind": "compose",
        "compose": ["day4-logs/docker-compose.yml"],
        "tag": "learning-week:day4-logs",
        "weight": "light",
    },
    5: {
        "title": "Custom Metrics",
        "subtitle": "Dynamic Challenge",
        "kind": "compose",
        "compose": [
            "day5-dynamic/lab-a-ecommerce/docker-compose.yml",
            "day5-dynamic/lab-b-iot/docker-compose.yml",
        ],
        "tag": "learning-week:day5-ecommerce",
        "weight": "light",
    },
}

# (action, day) -> script filename at the repo root. Nothing else is runnable.
SCRIPTS = {
    ("setup", 1): "setup_day1_apm.sh",
    ("setup", 2): "setup_day2_containers.sh",
    ("setup", 3): "setup_day3_dbm.sh",
    ("setup", 4): "setup_day4_logs.sh",
    ("setup", 5): "setup_day5_dynamic.sh",
    ("stop", 1): "stop_day1_apm.sh",
    ("stop", 2): "stop_day2_containers.sh",
    ("stop", 3): "stop_day3_dbm.sh",
    ("stop", 4): "stop_day4_logs.sh",
    ("stop", 5): "stop_day5_dynamic.sh",
    ("check", 1): "check_day1_apm.sh",
    ("check", 2): "check_day2_containers.sh",
    ("check", 3): "check_day3_dbm.sh",
    ("check", 4): "check_day4_logs.sh",
    ("check", 5): "check_day5_dynamic.sh",
    ("cleanup", 1): "cleanup_day1_apm.sh",
    ("cleanup", 2): "cleanup_day2_containers.sh",
    ("cleanup", 3): "cleanup_day3_dbm.sh",
    ("cleanup", 4): "cleanup_day4_logs.sh",
    ("cleanup", 5): "cleanup_day5_dynamic.sh",
}

STEP_RE = re.compile(rb"\[(\d+)/(\d+)\]")
ANSI_RE = re.compile(r"\x1b\[[0-9;?]*[A-Za-z]")

# Known failures, most specific first. Each one turns a wall of script output
# into a sentence someone can act on. Everything the participant reads is
# English on purpose, since the whole curriculum is delivered in English.
FAILURES = [
    (r"Docker is not running|Cannot connect to the Docker daemon|"
     r"docker daemon is not running|Is the docker daemon running",
     "Docker is not running",
     "The lab needs Docker to create its containers, and the Docker engine is not "
     "responding right now.",
     ["Open Docker Desktop and wait until it says Engine running.",
      "Come back here and press Start again."]),

    (r"port is already allocated|address already in use|Bind for .* failed",
     "A port this lab needs is already taken",
     "Another program on your machine is already listening on one of the ports this "
     "lab uses. Docker will not start a second container on the same port.",
     ["Stop the other day if one is still running, using its Stop button.",
      "If nothing else is running, the port belongs to another app on your machine. "
      "Quit that app, then press Start again."]),

    (r"DD_API_KEY not set|DD_APP_KEY not set|DD_API_KEY.*parameter null",
     "Your Datadog keys are missing",
     "The setup script could not find your API key or application key in the .env file.",
     ["Open the Datadog credentials panel at the top of this page.",
      "Paste both keys, press Save, then press Test connection.",
      "Once the test passes, press Start again."]),

    (r"403 Forbidden|\"errors\":\s*\[\s*\"Forbidden\"|Authentication error|"
     r"API key is not valid|invalid api key",
     "Datadog rejected your keys",
     "The containers started, but Datadog refused the request that creates the lab "
     "monitors. That normally means the application key is wrong, lacks permission to "
     "write monitors, or belongs to a different Datadog site than the one selected.",
     ["Open the credentials panel and press Test connection to see which key is at fault.",
      "Check that the site matches the address you log in to.",
      "Make sure the application key can read and write monitors.",
      "Fix the key, then press Clean and Start again."]),

    (r"no space left on device|No space left on device",
     "Your disk is full",
     "Docker ran out of room while unpacking the lab images.",
     ["Run docker system prune -a in a terminal to remove images you no longer use.",
      "Free up space on your disk, then press Start again."]),

    (r"Requested memory allocation.*is less than|insufficient memory|"
     r"Docker Desktop has only|not enough memory|cannot allocate memory|"
     r"Exiting due to RSRC_INSUFFICIENT",
     "Docker does not have enough memory",
     "This day builds a Kubernetes cluster, which needs noticeably more memory than "
     "the other days. Docker Desktop is currently allowed less than that.",
     ["Stop any other day that is still running.",
      "In Docker Desktop, open Settings, then Resources, and raise the memory limit "
      "to at least 8 GB.",
      "Docker will restart. Then press Start again."]),

    (r"command not found|: not found|executable file not found",
     "A required tool is not installed",
     "The setup script called a command that does not exist on this machine. The "
     "missing tool is named on the last line of the output below.",
     ["Install the missing tool. This week needs docker, kubectl, minikube, helm, "
      "curl and jq.",
      "On macOS, brew install <tool> covers all of them.",
      "Then press Start again."]),

    (r"Temporary failure in name resolution|could not resolve host|"
     r"network is unreachable|Connection timed out after|dial tcp.*i/o timeout",
     "Your machine could not reach the network",
     "The setup needs to download container images and talk to Datadog, and one of "
     "those calls could not get out.",
     ["Check your internet connection, and your VPN if you use one.",
      "Then press Start again."]),

    (r"pull access denied|manifest unknown|manifest for .* not found|"
     r"failed to solve|toomanyrequests",
     "A container image could not be downloaded",
     "Docker could not pull one of the images this lab is built from. This is usually "
     "a temporary registry problem or a Docker Hub rate limit.",
     ["Wait a minute and press Start again.",
      "If it keeps failing, run docker login in a terminal, since signing in raises "
      "the download limit."]),

    (r"timed out waiting for the condition|context deadline exceeded|"
     r"error: timed out waiting",
     "Something took too long to become ready",
     "The containers were created but one of them did not report itself healthy "
     "before the script gave up. On a busy machine this is often just slowness "
     "rather than a real fault.",
     ["Press Check to see what is actually running now.",
      "If most of it is up, give it two minutes and press Check again.",
      "If it is still stuck, press Clean and then Start."]),
]


def diagnose(output, returncode, action="setup", day=0):
    """Turn script output into a friendly explanation of what went wrong.

    `action` matters. A check that exits non-zero because the lab is simply not
    running is reporting the truth, not failing, so it must not be dressed up as
    an error.
    """
    if returncode is not None and returncode < 0:
        return {
            "title": "Cancelled",
            "explanation": "You stopped this run before it finished, so the lab is "
                           "probably half built.",
            "steps": ["Press Clean to tidy up, then Start when you are ready."],
            "tail": "",
            "soft": False,
        }

    text = ANSI_RE.sub("", output)
    lines = [ln.rstrip() for ln in text.splitlines() if ln.strip()]
    tail = "\n".join(lines[-14:])

    # A check on something that was never started, or was stopped, is a normal
    # answer. minikube in particular exits 7 for a stopped cluster.
    if action == "check" and re.search(
            r"host:\s*Stopped|kubelet:\s*Stopped|Profile .* not found|"
            r"no such (container|cluster)|not created|is not running", text, re.I):
        return {
            "title": f"Day {day} is not running" if day else "That lab is not running",
            "explanation": "Nothing is wrong. The check looked for the lab and found it "
                           "stopped or not created yet.",
            "steps": ["Press Start when you want to bring it up."],
            "tail": tail,
            "soft": True,
        }

    # Search the last part of the output first: the real cause is near the end,
    # and an early warning should not outrank the line that actually failed.
    for window in (lines[-40:], lines):
        blob = "\n".join(window)
        for pattern, title, explanation, steps in FAILURES:
            if re.search(pattern, blob, re.I):
                return {"title": title, "explanation": explanation,
                        "steps": steps, "tail": tail, "soft": False}

    if action == "check":
        return {
            "title": f"Day {day} did not pass its check" if day else "The check did not pass",
            "explanation": "The check script reported a problem that the panel does not "
                           "recognise. The last lines of its output are below.",
            "steps": ["Read the output below.",
                      "If the lab should be running, press Clean and then Start."],
            "tail": tail,
            "soft": True,
        }

    return {
        "title": "The script stopped with an error",
        "explanation": f"It exited with code {returncode}, and this was not a failure the "
                       "panel recognises. The last lines of its output are below and "
                       "usually name the cause.",
        "steps": ["Read the output below for the first line mentioning an error.",
                  "Press Clean, then Start, to retry from a clean state.",
                  "If it fails the same way again, show these lines to your facilitator."],
        "tail": tail,
        "soft": False,
    }

_lock = threading.Lock()
_job = None


class Job:
    def __init__(self, action, day, script, stdin_text=None):
        self.action = action
        self.day = day
        self.script = script
        self.label = f"{action} day {day}" if day else action
        self.started = time.time()
        self.finished = None
        self.returncode = None
        self.step = 0
        self.total = 0
        self.buf = bytearray()
        self.proc = None
        self._stdin_text = stdin_text
        self._thread = threading.Thread(target=self._run, daemon=True)

    def _run(self):
        path = os.path.join(ROOT, self.script)
        try:
            os.chmod(path, 0o755)
        except OSError:
            pass
        try:
            self.proc = subprocess.Popen(
                ["bash", path],
                cwd=ROOT,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                stdin=subprocess.PIPE if self._stdin_text else subprocess.DEVNULL,
                env={**os.environ, "TERM": "dumb", "NO_COLOR": "1"},
            )
        except OSError as exc:
            self.buf += f"failed to launch {self.script}: {exc}\n".encode()
            self.returncode = 127
            self.finished = time.time()
            return

        if self._stdin_text:
            try:
                self.proc.stdin.write(self._stdin_text.encode())
                self.proc.stdin.flush()
                self.proc.stdin.close()
            except OSError:
                pass

        for raw in iter(self.proc.stdout.readline, b""):
            self.buf += raw
            m = STEP_RE.search(raw)
            if m:
                self.step = int(m.group(1))
                self.total = int(m.group(2))
            if len(self.buf) > 4_000_000:
                del self.buf[: len(self.buf) - 2_000_000]

        self.proc.stdout.close()
        self.returncode = self.proc.wait()
        self.finished = time.time()

    def start(self):
        self._thread.start()

    @property
    def running(self):
        return self.finished is None

    def percent(self):
        if self.total:
            return min(100, int(100 * self.step / self.total))
        if self.running:
            return 5
        # A script that never printed a step marker: only claim completion if
        # it actually succeeded, so a failure is never drawn as a full bar.
        return 100 if self.returncode == 0 else 0

    def cancel(self):
        if self.proc and self.running:
            self.proc.terminate()

    def summary(self):
        out = {
            "action": self.action,
            "day": self.day,
            "label": self.label,
            "running": self.running,
            "returncode": self.returncode,
            "step": self.step,
            "total": self.total,
            "percent": self.percent(),
            "elapsed": int((self.finished or time.time()) - self.started),
            "bytes": len(self.buf),
            "failure": None,
        }
        if not self.running and self.returncode != 0:
            out["failure"] = diagnose(
                bytes(self.buf).decode("utf-8", "replace"),
                self.returncode, self.action, self.day)
        return out


def _run(cmd, timeout=25):
    try:
        p = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True, timeout=timeout)
        return p.returncode, p.stdout.strip(), p.stderr.strip()
    except (subprocess.TimeoutExpired, OSError) as exc:
        return 1, "", str(exc)


# --------------------------------------------------------------------------
# Credentials.
#
# The keys live in .env at the repo root, which is what every lab script
# already reads, and which .gitignore excludes. Two rules hold everywhere
# below: a key value is never written to the log buffer, the terminal, or any
# API response, and .env is created with owner-only permissions.
# --------------------------------------------------------------------------

ENV_PATH = os.path.join(ROOT, ".env")
PLACEHOLDER_RE = re.compile(r"^(your[_-]|<|\.\.\.|xxx)", re.I)
DD_SITES = [
    "datadoghq.com",
    "us3.datadoghq.com",
    "us5.datadoghq.com",
    "datadoghq.eu",
    "ap1.datadoghq.com",
    "ap2.datadoghq.com",
    "ddog-gov.com",
]


def read_env():
    """Return the .env keys as a dict. Missing file gives an empty dict."""
    out = {}
    try:
        with open(ENV_PATH, encoding="utf-8", errors="replace") as fh:
            for line in fh:
                line = line.strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                k, v = line.split("=", 1)
                out[k.strip()] = v.strip().strip('"').strip("'")
    except OSError:
        pass
    return out


def _is_real(value):
    return bool(value) and not PLACEHOLDER_RE.match(value)


def write_env(updates):
    """Update or append keys in .env, leaving every other line untouched."""
    lines = []
    if os.path.isfile(ENV_PATH):
        try:
            with open(ENV_PATH, encoding="utf-8", errors="replace") as fh:
                lines = fh.read().splitlines()
        except OSError as exc:
            return False, f"could not read .env: {exc}"
    elif os.path.isfile(ENV_PATH + ".example"):
        try:
            with open(ENV_PATH + ".example", encoding="utf-8", errors="replace") as fh:
                lines = fh.read().splitlines()
        except OSError:
            lines = []

    remaining = dict(updates)
    for i, line in enumerate(lines):
        stripped = line.strip()
        if not stripped or stripped.startswith("#") or "=" not in stripped:
            continue
        key = stripped.split("=", 1)[0].strip()
        if key in remaining:
            lines[i] = f"{key}={remaining.pop(key)}"
    for key, value in remaining.items():
        lines.append(f"{key}={value}")

    tmp = ENV_PATH + ".tmp"
    try:
        fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            fh.write("\n".join(lines).rstrip("\n") + "\n")
        os.replace(tmp, ENV_PATH)
        os.chmod(ENV_PATH, 0o600)
    except OSError as exc:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        return False, f"could not write .env: {exc}"
    return True, "saved"


def check_key_shape(kind, value):
    """Catch the paste mistakes, not the format itself.

    A Datadog API key is 32 hex characters and an application key is 40, but
    the check stays a hint rather than a hard rule so a future format change
    cannot lock anyone out. Whitespace and quotes are rejected outright
    because they are always a copy-paste accident and they always break .env.
    """
    expected = 32 if kind == "api" else 40
    label = "API key" if kind == "api" else "application key"
    if not value:
        return False, f"the {label} is empty"
    if any(c.isspace() for c in value):
        return False, f"the {label} contains a space or line break, remove it"
    if value[0] in "\"'" or value[-1] in "\"'":
        return False, f"remove the quotes around the {label}"
    if PLACEHOLDER_RE.match(value):
        return False, f"that is still the placeholder text, not a real {label}"
    if len(value) != expected:
        return False, (f"a Datadog {label} is {expected} characters, "
                       f"this one is {len(value)}, check for a truncated paste")
    if not re.fullmatch(r"[0-9a-fA-F]+", value):
        return False, f"a Datadog {label} uses only the characters 0 to 9 and a to f"
    return True, "looks right"


def credentials_state():
    """Whether each key is set, and never any part of its value.

    No fragment of a stored key is sent to the browser, not even a masked tail.
    Everyone brings their own keys, so the form always starts empty and shows
    nothing that could look pre-filled.
    """
    env = read_env()
    return {
        "api_key_set": _is_real(env.get("DD_API_KEY", "")),
        "app_key_set": _is_real(env.get("DD_APP_KEY", "")),
        "site": env.get("DD_SITE", "") or "datadoghq.com",
        "sites": DD_SITES,
        "env_exists": os.path.isfile(ENV_PATH),
    }


def _get_json(url, headers, timeout=15):
    req = urllib.request.Request(url, headers=headers, method="GET")
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return resp.status, resp.read(4096)
    except urllib.error.HTTPError as exc:
        return exc.code, b""
    except (urllib.error.URLError, OSError, ValueError) as exc:
        return 0, str(exc).encode()


def verify_credentials(api_key, app_key, site):
    """Ask Datadog whether the keys work, so nobody discovers a typo ten
    minutes into a setup run. Two calls: the documented API key validation
    endpoint, then a monitors read, which is the exact permission the labs
    need in order to create their monitors."""
    site = site or "datadoghq.com"
    base = f"https://api.{site}"
    result = {"api_key": None, "app_key": None, "site": site, "messages": []}

    status, body = _get_json(base + "/api/v1/validate", {"DD-API-KEY": api_key})
    if status == 0:
        result["api_key"] = "unknown"
        result["messages"].append(
            f"Could not reach {base}. Check your network, or the site setting if you "
            f"are not on {site}.")
        return result
    if status == 200 and b'"valid":true' in body.replace(b" ", b""):
        result["api_key"] = "valid"
    elif status in (401, 403):
        result["api_key"] = "invalid"
        result["messages"].append(
            f"{base} rejected the API key. If the key itself is right, the site is "
            f"probably wrong, since a key only works on the org that issued it.")
        return result
    else:
        result["api_key"] = "unknown"
        result["messages"].append(f"Unexpected reply from the validation endpoint: HTTP {status}.")

    if not app_key:
        result["app_key"] = "missing"
        return result

    status, _ = _get_json(
        base + "/api/v1/monitor/search?query=&per_page=1",
        {"DD-API-KEY": api_key, "DD-APPLICATION-KEY": app_key},
    )
    if status == 200:
        result["app_key"] = "valid"
    elif status == 403:
        result["app_key"] = "no_permission"
        result["messages"].append(
            "The application key is recognised but it cannot read monitors. The labs "
            "create and read monitors, so the key needs monitors_read and monitors_write.")
    elif status in (401, 400):
        result["app_key"] = "invalid"
        result["messages"].append("Datadog rejected the application key.")
    elif status == 0:
        result["app_key"] = "unknown"
        result["messages"].append("Could not reach Datadog for the application key check.")
    else:
        result["app_key"] = "unknown"
        result["messages"].append(f"Unexpected reply from the monitors endpoint: HTTP {status}.")
    return result


def _env_keys_present():
    cs = credentials_state()
    if not cs["env_exists"]:
        return False, "no .env file yet, fill in the credentials form above"
    missing = []
    if not cs["api_key_set"]:
        missing.append("DD_API_KEY")
    if not cs["app_key_set"]:
        missing.append("DD_APP_KEY")
    if missing:
        return False, "not set in .env: " + ", ".join(missing)
    return True, f"both keys set, site {cs['site']}"


def preflight():
    checks = []

    have_docker = shutil.which("docker") is not None
    checks.append({
        "id": "docker-installed",
        "label": "Docker CLI installed",
        "ok": have_docker,
        "detail": "found on PATH" if have_docker else "docker not found on PATH",
    })

    docker_up = False
    docker_detail = "skipped, Docker CLI not installed"
    mem_gib = None
    if have_docker:
        rc, out, _ = _run(["docker", "info", "--format", "{{.MemTotal}}"], timeout=20)
        docker_up = rc == 0 and out.isdigit()
        if docker_up:
            mem_gib = round(int(out) / (1024 ** 3), 1)
            docker_detail = f"engine running, {mem_gib} GiB available to containers"
        else:
            docker_detail = "engine not responding, start Docker and retry"
    checks.append({
        "id": "docker-running",
        "label": "Docker engine running",
        "ok": docker_up,
        "detail": docker_detail,
    })

    keys_ok, keys_detail = _env_keys_present()
    checks.append({
        "id": "credentials",
        "label": "Datadog keys in .env",
        "ok": keys_ok,
        "detail": keys_detail,
    })

    have_minikube = shutil.which("minikube") is not None
    checks.append({
        "id": "minikube",
        "label": "minikube installed, Day 2 only",
        "ok": have_minikube,
        "detail": "found on PATH" if have_minikube else "not found, Day 2 setup will install it",
        "advisory": True,
    })

    blocking = [c for c in checks if not c["ok"] and not c.get("advisory")]
    return {
        "checks": checks,
        "ready": not blocking,
        "memory_gib": mem_gib,
    }


def day_status(num):
    spec = DAYS[num]
    if spec["kind"] == "minikube":
        if shutil.which("minikube") is None:
            return "down", "minikube not installed"
        rc, out, _ = _run(["minikube", "status", "-p", MINIKUBE_PROFILE], timeout=25)
        text = out.lower()
        if "host: running" in text and "kubelet: running" in text:
            return "up", "cluster running"
        if "host: stopped" in text or "kubelet: stopped" in text:
            return "stopped", "cluster exists but is stopped"
        return "down", "no cluster"

    if shutil.which("docker") is None:
        return "down", "Docker not installed"
    total = 0
    running = 0
    for rel in spec["compose"]:
        path = os.path.join(ROOT, rel)
        if not os.path.isfile(path):
            continue
        rc, out, _ = _run(["docker", "compose", "-f", path, "ps", "-q"], timeout=25)
        ids = [x for x in out.splitlines() if x.strip()]
        total += len(ids)
        rc2, out2, _ = _run(
            ["docker", "compose", "-f", path, "ps", "-q", "--status", "running"], timeout=25)
        running += len([x for x in out2.splitlines() if x.strip()])
    if running and running == total:
        return "up", f"{running} containers running"
    if running:
        return "partial", f"{running} of {total} containers running"
    if total:
        return "stopped", f"{total} containers exist but are stopped"
    return "down", "not created"


def full_state():
    pre = preflight()
    days = {}
    for num in sorted(DAYS):
        state, detail = day_status(num)
        # Only what the cards render. The subtitle, weight and tag entries in
        # DAYS stay there to describe each day for whoever edits this file, but
        # nothing displays them, so they are not shipped to the browser.
        days[str(num)] = {
            "num": num,
            "title": DAYS[num]["title"],
            "state": state,
            "detail": detail,
        }
    active = [d["num"] for d in days.values() if d["state"] in ("up", "partial")]
    with _lock:
        job = _job.summary() if _job else None
    return {
        "preflight": pre,
        "credentials": credentials_state(),
        "days": days,
        "active_days": active,
        "job": job,
        "root": ROOT,
    }


class Handler(BaseHTTPRequestHandler):
    server_version = "LearningWeekLabControl/1.0"

    def log_message(self, fmt, *args):
        pass

    def _send(self, code, body, ctype="application/json; charset=utf-8"):
        if isinstance(body, (dict, list)):
            body = json.dumps(body).encode()
        elif isinstance(body, str):
            body = body.encode()
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        try:
            self.wfile.write(body)
        except BrokenPipeError:
            pass

    def do_GET(self):
        u = urlparse(self.path)
        if u.path in ("/", "/index.html"):
            path = os.path.join(UI_DIR, "index.html")
            try:
                with open(path, "rb") as fh:
                    return self._send(200, fh.read(), "text/html; charset=utf-8")
            except OSError:
                return self._send(500, "index.html is missing next to server.py", "text/plain")

        if u.path == "/api/state":
            return self._send(200, full_state())

        if u.path == "/api/log":
            q = parse_qs(u.query)
            try:
                offset = max(0, int(q.get("offset", ["0"])[0]))
            except ValueError:
                offset = 0
            with _lock:
                job = _job
            if not job:
                return self._send(200, {"offset": 0, "chunk": "", "job": None})
            data = bytes(job.buf)
            chunk = data[offset:] if offset <= len(data) else b""
            return self._send(200, {
                "offset": len(data),
                "chunk": chunk.decode("utf-8", "replace"),
                "job": job.summary(),
            })

        return self._send(404, {"error": "not found"})

    def _body(self):
        try:
            n = int(self.headers.get("Content-Length") or 0)
        except ValueError:
            n = 0
        if not n:
            return {}
        try:
            return json.loads(self.rfile.read(n) or b"{}")
        except (ValueError, OSError):
            return {}

    def do_POST(self):
        global _job
        u = urlparse(self.path)
        payload = self._body()

        if u.path == "/api/run":
            action = str(payload.get("action", ""))
            try:
                day = int(payload.get("day", 0))
            except (TypeError, ValueError):
                return self._send(400, {"error": "day must be a number"})
            key = (action, day)
            if key not in SCRIPTS:
                return self._send(400, {"error": f"unknown action {action} for day {day}"})

            if action == "setup":
                pre = preflight()
                if not pre["ready"]:
                    bad = [c["label"] for c in pre["checks"]
                           if not c["ok"] and not c.get("advisory")]
                    return self._send(409, {
                        "error": "preflight failed",
                        "detail": "resolve these first: " + ", ".join(bad),
                    })
                if not payload.get("force"):
                    others = [n for n in DAYS
                              if n != day and day_status(n)[0] in ("up", "partial")]
                    if others:
                        return self._send(409, {
                            "error": "another day is running",
                            "conflict_days": others,
                            "detail": "The whole week does not fit in memory at once. "
                                      "Stop the running day first.",
                        })

            with _lock:
                if _job and _job.running:
                    return self._send(409, {
                        "error": "a job is already running",
                        "detail": _job.label,
                    })
                _job = Job(action, day, SCRIPTS[key])
                _job.start()
            return self._send(200, {"started": True, "job": _job.summary()})

        if u.path == "/api/destroy":
            if str(payload.get("confirm", "")) != "DESTROY":
                return self._send(400, {
                    "error": "confirmation required",
                    "detail": 'send {"confirm":"DESTROY"}',
                })
            with _lock:
                if _job and _job.running:
                    return self._send(409, {
                        "error": "a job is already running",
                        "detail": _job.label,
                    })
                # reset.sh asks for interactive confirmation; the UI already
                # collected it, so answer its prompt and nothing else.
                _job = Job("destroy", 0, "reset.sh", stdin_text="y\n")
                _job.start()
            return self._send(200, {"started": True, "job": _job.summary()})

        if u.path == "/api/credentials":
            api_key = str(payload.get("api_key", "")).strip()
            app_key = str(payload.get("app_key", "")).strip()
            site = str(payload.get("site", "")).strip() or "datadoghq.com"
            if site not in DD_SITES:
                return self._send(400, {"error": f"unknown Datadog site {site}"})

            current = read_env()
            updates = {"DD_SITE": site}

            # An empty field means "keep whatever is already saved", so nobody
            # has to retype a key just to change the site.
            for kind, field, envvar in (("api", api_key, "DD_API_KEY"),
                                        ("app", app_key, "DD_APP_KEY")):
                if field:
                    ok, why = check_key_shape(kind, field)
                    if not ok:
                        return self._send(400, {"error": why})
                    updates[envvar] = field
                elif not _is_real(current.get(envvar, "")):
                    label = "API key" if kind == "api" else "application key"
                    return self._send(400, {"error": f"the {label} is still missing"})

            ok, why = write_env(updates)
            if not ok:
                return self._send(500, {"error": why})

            # Verify what is now on disk, so a save is confirmed in one step and
            # nobody has to paste the keys again just to check them.
            saved = read_env()
            verification = verify_credentials(
                saved.get("DD_API_KEY", ""), saved.get("DD_APP_KEY", ""), site)
            return self._send(200, {
                "saved": True,
                "credentials": credentials_state(),
                "verification": verification,
            })

        if u.path == "/api/credentials/test":
            # This tests only what was typed into the boxes. It must never fall
            # back to whatever is already in .env, because then an empty form
            # would report "works" and look like it had validated the blanks.
            api_key = str(payload.get("api_key", "")).strip()
            app_key = str(payload.get("app_key", "")).strip()
            site = str(payload.get("site", "")).strip() or "datadoghq.com"
            if site not in DD_SITES:
                return self._send(400, {"error": f"unknown Datadog site {site}"})
            if not api_key or not app_key:
                return self._send(400, {"error": (
                    "Paste both keys into the boxes above first. This button only checks "
                    "what you typed, never anything already saved.")})
            for kind, value in (("api", api_key), ("app", app_key)):
                ok, why = check_key_shape(kind, value)
                if not ok:
                    return self._send(400, {"error": why})
            return self._send(200, verify_credentials(api_key, app_key, site))

        if u.path == "/api/cancel":
            with _lock:
                if not _job or not _job.running:
                    return self._send(409, {"error": "nothing is running"})
                _job.cancel()
            return self._send(200, {"cancelled": True})

        return self._send(404, {"error": "not found"})


def main():
    missing = [s for s in set(SCRIPTS.values()) | {"reset.sh"}
               if not os.path.isfile(os.path.join(ROOT, s))]
    if missing:
        print("These scripts are missing from the repo root, so the UI cannot drive them:")
        for m in sorted(missing):
            print("  ", m)
        print("\nRun this from inside the Learning Week folder.")
        return 1

    try:
        srv = ThreadingHTTPServer((HOST, PORT), Handler)
    except OSError as exc:
        print(f"Could not listen on {HOST}:{PORT}: {exc}\n")
        print("Most likely the panel is already running in another window.")
        print(f"Try opening http://{HOST}:{PORT} first.")
        print(f"To use a different port: LAB_UI_PORT=8766 python3 lab-ui/server.py")
        return 1

    url = f"http://{HOST}:{PORT}"
    print("=" * 62)
    print("  Monitors and Metrics Learning Week")
    print("=" * 62)
    print(f"  Repo:  {ROOT}")
    print(f"  Open:  {url}")
    print("  Stop:  Ctrl+C")
    print("=" * 62)

    # Opening the browser here rather than in each launcher keeps the Windows,
    # macOS and Linux entry points identical, and it fires only once the socket
    # is already bound so the first request cannot race the server.
    if os.environ.get("LAB_UI_NO_BROWSER") != "1":
        threading.Timer(0.6, lambda: webbrowser.open(url)).start()

    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down. Any lab you started keeps running.")
    finally:
        srv.server_close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
