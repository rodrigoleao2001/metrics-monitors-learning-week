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
     "The lab needs a container runtime to create its containers, and the engine is "
     "not responding right now.",
     ["Start your runtime. Colima: colima start. A desktop runtime: open it and wait "
      "until it reports that its engine is running.",
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
     "Your container runtime does not have enough memory",
     "This day builds a Kubernetes cluster, which needs noticeably more memory than "
     "the other days, and the runtime is allowed less than that. Under Colima the "
     "cluster runs inside the Colima VM, so the VM has to be larger than the cluster "
     "it holds.",
     ["Stop any other day that is still running.",
      "Colima: colima stop, then colima start --cpu 4 --memory 12 --disk 60.",
      "A desktop runtime: Settings, then Resources, raise memory to at least 8 GB.",
      "Then press Start again."]),

    (r"command not found|: not found|executable file not found",
     "A required tool is not installed",
     "The setup script called a command that does not exist on this machine. The "
     "missing tool is named on the last line of the output below.",
     ["Install the missing tool. This week needs a container runtime plus docker, "
      "docker-compose, kubectl, minikube, helm, "
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


def job_env():
    """Environment for a lab run: the keys from the keychain, for this run only.

    The scripts still `source .env`, but .env no longer defines the keys, so
    sourcing it cannot overwrite what is injected here.
    """
    env = {**os.environ, "TERM": "dumb", "NO_COLOR": "1"}
    api, app = stored_keys()
    if api:
        env["DD_API_KEY"] = api
    if app:
        env["DD_APP_KEY"] = app
    env.setdefault("DD_SITE", read_env().get("DD_SITE") or "datadoghq.com")
    return env


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
                env=job_env(),
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

# --------------------------------------------------------------------------
# Where the keys live.
#
# Not in .env. On macOS they go into the login keychain, which is encrypted at
# rest and unlocked by the login password, and .env keeps only DD_SITE, which is
# not a secret. The panel reads them back only when it has to: to verify them,
# to reveal one on request, and to hand them to a lab script as environment
# variables for that one run.
#
# Two honest limits. The `security` CLI takes the value as an argument, so it is
# briefly visible to `ps` for this same user during the write. And once a lab is
# running, the Agent container holds the API key in its own environment, where
# `docker inspect` can read it: that is inherent to the Agent needing the key,
# not something this storage choice can fix.
# --------------------------------------------------------------------------

KEYCHAIN_SERVICE = "learning-week-datadog"
USE_KEYCHAIN = sys.platform == "darwin" and shutil.which("security") is not None


def keychain_get(account):
    if not USE_KEYCHAIN:
        return ""
    p = subprocess.run(
        ["security", "find-generic-password", "-s", KEYCHAIN_SERVICE,
         "-a", account, "-w"],
        capture_output=True, text=True)
    return p.stdout.strip() if p.returncode == 0 else ""


def keychain_set(account, value):
    if not USE_KEYCHAIN:
        return False, "the login keychain is not available on this platform"
    p = subprocess.run(
        ["security", "add-generic-password", "-U", "-s", KEYCHAIN_SERVICE,
         "-a", account, "-w", value,
         "-D", "Learning Week lab credential",
         "-j", "Stored by the Learning Week lab control panel"],
        capture_output=True, text=True)
    if p.returncode != 0:
        return False, (p.stderr or p.stdout).strip()[:200]
    return True, "stored in the login keychain"


def keychain_delete(account):
    if not USE_KEYCHAIN:
        return
    subprocess.run(["security", "delete-generic-password",
                    "-s", KEYCHAIN_SERVICE, "-a", account],
                   capture_output=True, text=True)


def stored_keys():
    """The two keys, from the keychain. Values never leave this process except
    through the explicit reveal endpoint and the job environment."""
    return keychain_get("DD_API_KEY"), keychain_get("DD_APP_KEY")
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

    A Datadog API key is 32 hex characters. An application key is 40
    characters, but that 40 now covers two real shapes: the legacy 40 hex
    characters, and the newer `ddapp_` prefix followed by 34 alphanumeric
    characters (mixed case), which is not hex and would otherwise be
    rejected. Reported by Edwards Rodriguez, whose real ddapp_-style key was
    failing this check. The length gate above stays a hint rather than a
    hard rule so a future format change cannot lock anyone out. Whitespace
    and quotes are rejected outright because they are always a copy-paste
    accident and they always break .env.
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
    if kind == "app":
        if not re.fullmatch(r"ddapp_[0-9A-Za-z]{34}|[0-9a-fA-F]{40}", value):
            return False, (f"a Datadog {label} is either 40 hex characters (0-9, a-f) "
                           "or the newer ddapp_ prefix followed by 34 letters/digits")
    elif not re.fullmatch(r"[0-9a-fA-F]+", value):
        return False, f"a Datadog {label} uses only the characters 0 to 9 and a to f"
    return True, "looks right"


def mask_key(value):
    """A display form of a stored key: dots, then its last four characters.

    The real key is never sent to the browser. Four characters out of a 32 or 40
    character hex key is the usual way to let someone recognise which key is
    stored, and it leaves the key itself far out of reach.
    """
    if not _is_real(value):
        return ""
    if len(value) <= 8:
        return "•" * len(value)
    return "•" * (len(value) - 4) + value[-4:]


def credentials_state():
    env = read_env()
    api, app = stored_keys()
    return {
        "api_key_set": _is_real(api),
        "app_key_set": _is_real(app),
        "api_key_mask": mask_key(api),
        "app_key_mask": mask_key(app),
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
    if not USE_KEYCHAIN:
        return False, ("this platform has no login keychain, so the panel cannot "
                       "store keys securely")
    missing = []
    if not cs["api_key_set"]:
        missing.append("DD_API_KEY")
    if not cs["app_key_set"]:
        missing.append("DD_APP_KEY")
    if missing:
        return False, "not in the keychain yet: " + ", ".join(missing)
    return True, f"both keys in the login keychain, site {cs['site']}"


# --------------------------------------------------------------------------
# Starting Docker.
#
# bootstrap.sh handles this by blocking on "press Enter when Docker Desktop
# shows Engine running", which a panel cannot do. So the panel launches the
# runtime itself and reports how far along it is, because the engine takes
# roughly half a minute to accept connections and a silent wait reads as a hang.
# --------------------------------------------------------------------------

# Datadog is removing Docker Desktop licences, with Colima as the recommended
# replacement and Rancher Desktop where local Kubernetes is needed. So Colima is
# tried first and Docker Desktop last: on a machine that still has both, the
# panel should not be the thing that keeps opening the paid product.
DOCKER_APPS = [
    "/Applications/Rancher Desktop.app",
    "/Applications/OrbStack.app",
    "/Applications/Docker.app",
    os.path.expanduser("~/Applications/Docker.app"),
]
DOCKER_BOOT_TIMEOUT = int(os.environ.get("LAB_UI_DOCKER_TIMEOUT", "150"))

# Day 2 asks minikube for 4096 MB across 2 nodes, and under Colima that cluster
# runs inside the Colima VM rather than beside it. An 8 GB VM cannot host an
# 8 GB cluster, so the VM is sized above it with headroom.
COLIMA_CPU = os.environ.get("LAB_UI_COLIMA_CPU", "4")
COLIMA_MEMORY = os.environ.get("LAB_UI_COLIMA_MEMORY", "12")
COLIMA_DISK = os.environ.get("LAB_UI_COLIMA_DISK", "60")

_docker_boot = {"state": "idle", "detail": "", "waited": 0, "runtime": ""}
_docker_lock = threading.Lock()


def docker_engine_up():
    rc, out, _ = _run(["docker", "info", "--format", "{{.ServerVersion}}"], timeout=20)
    return rc == 0 and bool(out.strip())


def docker_runtime():
    """Which local runtime this panel knows how to launch, if any.

    Colima wins when present, because it is the recommended default now. A
    desktop app is the fallback, Docker Desktop last within that list.
    """
    if shutil.which("colima"):
        return "colima", None
    if sys.platform == "darwin":
        for path in DOCKER_APPS:
            if os.path.isdir(path):
                return "app", path
    return None, None


def runtime_label():
    kind, path = docker_runtime()
    if kind == "colima":
        return "Colima"
    if kind == "app":
        return os.path.basename(path).replace(".app", "")
    return "your container runtime"


def memory_advice():
    """How to give the runtime more memory. The instruction differs per runtime,
    and pointing a Colima user at Docker Desktop settings just wastes their time."""
    kind, _ = docker_runtime()
    if kind == "colima":
        return (f"Give the Colima VM more memory: colima stop, then "
                f"colima start --cpu {COLIMA_CPU} --memory 12 --disk {COLIMA_DISK}")
    return ("Open your runtime's Settings, then Resources, and raise the memory "
            "limit to at least 8 GB")


def docker_boot_state():
    with _docker_lock:
        return dict(_docker_boot)


def _boot_docker():
    kind, path = docker_runtime()
    if kind is None:
        with _docker_lock:
            _docker_boot.update(
                state="unsupported", runtime="",
                detail="No Docker runtime here that the panel knows how to start.")
        return

    label = os.path.basename(path).replace(".app", "") if kind == "app" else "Colima"
    with _docker_lock:
        _docker_boot.update(state="starting", runtime=label, waited=0,
                            detail=f"Asking {label} to start")

    if kind == "app":
        _run(["open", "-a", path], timeout=30)
    else:
        try:
            subprocess.Popen(["colima", "start", "--cpu", COLIMA_CPU,
                              "--memory", COLIMA_MEMORY, "--disk", COLIMA_DISK],
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                             stdin=subprocess.DEVNULL)
        except OSError as exc:
            with _docker_lock:
                _docker_boot.update(state="failed", detail=f"Could not run colima: {exc}")
            return

    began = time.time()
    while time.time() - began < DOCKER_BOOT_TIMEOUT:
        if docker_engine_up():
            with _docker_lock:
                _docker_boot.update(state="ready", waited=int(time.time() - began),
                                    detail=f"{label} is running")
            return
        with _docker_lock:
            _docker_boot.update(waited=int(time.time() - began),
                                detail=f"Waiting for {label} to finish starting")
        time.sleep(3)

    with _docker_lock:
        _docker_boot.update(
            state="failed", waited=int(time.time() - began),
            detail=(f"{label} did not report a running engine within "
                    f"{DOCKER_BOOT_TIMEOUT} seconds. If this is its first launch it may "
                    f"be waiting for you to accept its licence agreement."))


def start_docker_async(force=False):
    """Kick off a start attempt. Returns why it declined, or None if it began."""
    with _docker_lock:
        if _docker_boot["state"] == "starting":
            return "Docker is already starting."
        if _docker_boot["state"] == "ready" and not force:
            return "Docker is already running."
    if docker_engine_up():
        with _docker_lock:
            _docker_boot.update(state="ready", detail="Docker is already running")
        return "Docker is already running."
    threading.Thread(target=_boot_docker, daemon=True).start()
    return None


# --------------------------------------------------------------------------
# State caching.
#
# preflight() and day_status() used to shell out to `docker info`, `docker
# compose ps` and `minikube status` directly inside the HTTP handler, on every
# single /api/state poll. That is fine when those commands answer in
# milliseconds, and a multi-second hang whenever Docker or Colima is slow to
# respond, which happens right after the VM starts or restarts. Because the
# front end polls this endpoint continuously, a single slow moment froze the
# entire panel, not just the one request that hit it: exactly what "the UI
# will not open" looks like from the outside.
#
# A background thread now does that work on a fixed interval and stores the
# result here. The HTTP handler only ever reads the cache, so a slow `docker
# info` call delays how fresh the number is, never how fast the page responds.
# --------------------------------------------------------------------------

_STATE_REFRESH_SECONDS = 2
_state_lock = threading.Lock()
_state_cache = {
    "docker_running": {"ok": False, "detail": "checking…", "mem_gib": None},
    "days": {n: ("checking", "checking…") for n in DAYS},
}


def _check_docker_running_live():
    """The actual subprocess call. Only ever invoked from the refresh thread."""
    if shutil.which("docker") is None:
        return {"ok": False, "detail": "skipped, Docker CLI not installed", "mem_gib": None}
    rc, out, _ = _run(["docker", "info", "--format", "{{.MemTotal}}"], timeout=20)
    if rc == 0 and out.isdigit():
        mem_gib = round(int(out) / (1024 ** 3), 1)
        return {"ok": True, "mem_gib": mem_gib,
                "detail": f"engine running, {mem_gib} GiB available to containers"}
    boot = docker_boot_state()
    if boot["state"] == "starting":
        detail = f"{boot['detail']}, {boot['waited']}s so far"
    elif boot["state"] in ("failed", "unsupported"):
        detail = boot["detail"]
    else:
        detail = "engine not responding"
    return {"ok": False, "detail": detail, "mem_gib": None}


def _day_status_live(num):
    """The actual subprocess calls for one day. Only from the refresh thread."""
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


def _state_refresh_loop():
    while True:
        try:
            dr = _check_docker_running_live()
            days = {n: _day_status_live(n) for n in DAYS}
            with _state_lock:
                _state_cache["docker_running"] = dr
                _state_cache["days"] = days
        except Exception:
            pass  # keep serving the previous snapshot rather than crash the loop
        time.sleep(_STATE_REFRESH_SECONDS)


def start_state_refresh_thread():
    threading.Thread(target=_state_refresh_loop, daemon=True).start()


def preflight():
    checks = []

    have_docker = shutil.which("docker") is not None
    checks.append({
        "id": "docker-installed",
        "label": "Container runtime",
        "ok": have_docker,
        "detail": (f"docker CLI on PATH, runtime {runtime_label()}" if have_docker
                   else "docker CLI not found on PATH"),
    })

    with _state_lock:
        dr = dict(_state_cache["docker_running"])
    checks.append({
        "id": "docker-running",
        "label": "Docker engine running",
        "ok": dr["ok"],
        "detail": dr["detail"],
        # Lets the panel show a spinner and hold the buttons instead of an alarm.
        "starting": (not dr["ok"]) and docker_boot_state()["state"] == "starting",
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
    boot = docker_boot_state()
    return {
        "checks": checks,
        "ready": not blocking,
        "memory_gib": dr["mem_gib"],
        "docker_boot": boot,
        # Can the panel offer to start the runtime for you at all?
        "can_start_docker": docker_runtime()[0] is not None,
        # So the UI never has to name a product the policy is moving away from.
        "runtime_label": runtime_label(),
        "memory_advice": memory_advice(),
    }


def day_status(num):
    with _state_lock:
        return _state_cache["days"].get(num, ("checking", "checking…"))


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


_server = None


def _shutdown():
    """Stop serving. Any lab already up keeps running: those are separate
    processes and Docker containers, not children of this one."""
    time.sleep(0.3)
    if _server is not None:
        _server.shutdown()


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

    def _origin_ok(self):
        """Reject a cross-origin browser request.

        Matters for the reveal endpoint: without this, a page the participant
        happens to be visiting could aim a simple POST at this port. A tool
        like curl sends no Origin at all, which is fine.
        """
        origin = self.headers.get("Origin")
        if not origin:
            return True
        return origin in (f"http://{HOST}:{PORT}", f"http://localhost:{PORT}")

    def do_POST(self):
        global _job
        u = urlparse(self.path)

        if not self._origin_ok():
            return self._send(403, {"error": "cross-origin requests are not accepted"})

        payload = self._body()

        if u.path == "/api/quit":
            with _lock:
                busy = _job is not None and _job.running
            if busy and not payload.get("force"):
                return self._send(409, {
                    "error": "a job is still running",
                    "detail": _job.label,
                })
            self._send(200, {"stopping": True})
            # Shut down from another thread: this one still has to finish
            # writing the response above.
            threading.Thread(target=_shutdown, daemon=True).start()
            return

        if u.path == "/api/credentials/reveal":
            # The key is sent only when the participant clicks Show, never on the
            # polling endpoints, so it is not sitting in the page the whole session.
            field = str(payload.get("field", ""))
            account = {"api": "DD_API_KEY", "app": "DD_APP_KEY"}.get(field)
            if not account:
                return self._send(400, {"error": "field must be api or app"})
            value = keychain_get(account)
            if not _is_real(value):
                return self._send(404, {"error": "nothing is stored for that field yet"})
            return self._send(200, {"field": field, "value": value})

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

        if u.path == "/api/docker/start":
            why = start_docker_async(force=bool(payload.get("force")))
            if why:
                return self._send(409, {"error": why, "docker_boot": docker_boot_state()})
            return self._send(200, {"starting": True, "docker_boot": docker_boot_state()})

        if u.path == "/api/credentials":
            api_key = str(payload.get("api_key", "")).strip()
            app_key = str(payload.get("app_key", "")).strip()
            site = str(payload.get("site", "")).strip() or "datadoghq.com"
            if site not in DD_SITES:
                return self._send(400, {"error": f"unknown Datadog site {site}"})

            if not USE_KEYCHAIN:
                return self._send(500, {"error": (
                    "This panel stores keys in the macOS login keychain, which is "
                    "not available here.")})

            stored_api, stored_app = stored_keys()
            # An empty field means "keep what is already stored", so nobody has
            # to retype a key just to change the site.
            for kind, field, account, existing in (
                    ("api", api_key, "DD_API_KEY", stored_api),
                    ("app", app_key, "DD_APP_KEY", stored_app)):
                if field:
                    ok, why = check_key_shape(kind, field)
                    if not ok:
                        return self._send(400, {"error": why})
                    ok, why = keychain_set(account, field)
                    if not ok:
                        return self._send(500, {"error": f"keychain write failed: {why}"})
                elif not _is_real(existing):
                    label = "API key" if kind == "api" else "application key"
                    return self._send(400, {"error": f"the {label} is still missing"})

            # .env carries the site only. It is not a secret and the lab scripts
            # read it directly.
            ok, why = write_env({"DD_SITE": site})
            if not ok:
                return self._send(500, {"error": why})

            # Verify what is now on disk, so a save is confirmed in one step and
            # nobody has to paste the keys again just to check them.
            saved_api, saved_app = stored_keys()
            verification = verify_credentials(saved_api, saved_app, site)
            return self._send(200, {
                "saved": True,
                "credentials": credentials_state(),
                "verification": verification,
            })

        if u.path == "/api/credentials/test":
            # Two explicit modes, never a silent fallback. Either the client sends
            # keys it wants checked, or it asks for the stored ones by name and the
            # answer is labelled as such, so a verdict can never be mistaken for a
            # verdict on an empty box.
            api_key = str(payload.get("api_key", "")).strip()
            app_key = str(payload.get("app_key", "")).strip()
            site = str(payload.get("site", "")).strip() or "datadoghq.com"
            if site not in DD_SITES:
                return self._send(400, {"error": f"unknown Datadog site {site}"})

            # A successful test against a given site is a declaration of intent
            # to use that site, so persist it here too, exactly like Save does.
            # Without this, switching the dropdown and testing without also
            # pressing Save leaves .env pointing at the old site: the test
            # reports success against the new one, but every lab script still
            # reads the stale DD_SITE and gets a 401 from the real run.
            write_env({"DD_SITE": site})

            if payload.get("use_saved") and not api_key and not app_key:
                api_key, app_key = stored_keys()
                if not _is_real(api_key) or not _is_real(app_key):
                    return self._send(400, {"error": (
                        "Nothing is saved yet. Paste both keys above, then press "
                        "Test connection.")})
                result = verify_credentials(api_key, app_key, site)
                result["source"] = "saved"
                return self._send(200, result)

            if not api_key or not app_key:
                return self._send(400, {"error": (
                    "Paste both keys into the boxes above first. This button only checks "
                    "what you typed, never anything already saved.")})
            for kind, value in (("api", api_key), ("app", app_key)):
                ok, why = check_key_shape(kind, value)
                if not ok:
                    return self._send(400, {"error": why})
            result = verify_credentials(api_key, app_key, site)
            result["source"] = "typed"
            return self._send(200, result)

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

    global _server
    try:
        srv = _server = ThreadingHTTPServer((HOST, PORT), Handler)
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
    # Detached there is no terminal to interrupt, so point at the right control.
    print("  Stop:  the Quit button in the panel"
          if os.environ.get("LAB_UI_DETACHED") == "1" else "  Stop:  Ctrl+C")
    print("=" * 62)

    # Opening the browser here rather than in each launcher keeps the Windows,
    # macOS and Linux entry points identical, and it fires only once the socket
    # is already bound so the first request cannot race the server.
    if os.environ.get("LAB_UI_NO_BROWSER") != "1":
        threading.Timer(0.6, lambda: webbrowser.open(url)).start()

    def _start_docker_in_background():
        # docker_engine_up() shells out to `docker info`, which can take
        # several seconds, longest right after Colima was stopped and the
        # daemon has to wake back up. Running this inline used to block here
        # BEFORE serve_forever() below, so the socket had accepted the
        # browser's connection but nothing was reading from it yet: the tab
        # would sit blank or spinning for however long that check took,
        # which is exactly what "the panel will not open" looks like. This
        # now runs after the server is already answering requests.
        if docker_engine_up():
            with _docker_lock:
                _docker_boot.update(state="ready", detail="Docker was already running")
            print("  Docker: already running")
        else:
            kind, path = docker_runtime()
            if kind:
                name = os.path.basename(path).replace(".app", "") if kind == "app" else "Colima"
                print(f"  Docker: not running, starting {name} for you")
                start_docker_async()
            else:
                print("  Docker: not running, and no runtime found to start")

    if os.environ.get("LAB_UI_NO_DOCKER_START") != "1":
        threading.Thread(target=_start_docker_in_background, daemon=True).start()

    # Starts filling in the real docker/day state in the background. The very
    # first poll or two may still show the "checking…" placeholders while the
    # first pass completes, but the request itself never waits on it.
    start_state_refresh_thread()

    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down. Any lab you started keeps running.")
    finally:
        srv.server_close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
