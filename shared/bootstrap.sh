#!/usr/bin/env bash
# shared/bootstrap.sh
# Source this from any setup_dayN.sh, then call run_bootstrap.
# Requires ROOT_DIR to be set by the calling script.
# Respects SKIP_BOOTSTRAP=1 (set by setup_all.sh to run bootstrap only once).

# Load guard — safe to source multiple times within the same shell process
[[ "${_LW_BOOTSTRAP_LOADED:-0}" == "1" ]] && return 0

# ── Formatting ────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

_STEP=0
_TOTAL_STEPS="${_TOTAL_STEPS:-12}"
step() { echo -e "\n${BLUE}${BOLD}[$((++_STEP))/${_TOTAL_STEPS}] $*${NC}"; }
ok()   { echo -e "  ${GREEN}✓${NC}  $*"; }
warn() { echo -e "  ${YELLOW}!${NC}  $*"; }
die()  { echo -e "\n${RED}✗  $*${NC}\n"; exit 1; }

# ── Package helpers ───────────────────────────────────────────────────────────
brew_install() {
    local pkg="$1"
    if brew list --formula "$pkg" >/dev/null 2>&1; then
        ok "$pkg already installed"
    else
        warn "Installing $pkg via Homebrew..."
        brew install "$pkg"
        ok "$pkg installed"
    fi
}

apt_install() {
    local pkg="$1"
    if dpkg -s "$pkg" >/dev/null 2>&1; then
        ok "$pkg already installed"
    else
        warn "Installing $pkg via apt..."
        sudo apt-get install -y -q "$pkg"
        ok "$pkg installed"
    fi
}

# ── Agent health helpers ──────────────────────────────────────────────────────

# wait_for_compose_agent COMPOSE_FILE [SERVICE_NAME] [TIMEOUT_SECS]
wait_for_compose_agent() {
    local compose_file="$1"
    local service="${2:-datadog-agent}"
    local timeout="${3:-90}"
    local polls=$(( timeout / 5 ))
    echo "  Polling agent status (up to ${timeout}s)..."
    local i
    for i in $(seq 1 "$polls"); do
        if docker compose -f "$compose_file" exec -T "$service" agent status >/dev/null 2>&1; then
            echo ""
            ok "Agent ($service) is healthy"
            return 0
        fi
        printf "  ."
        sleep 5
    done
    echo ""
    warn "Agent ($service) did not respond in ${timeout}s — continuing anyway."
    warn "Check: docker compose -f $compose_file logs $service"
}

# wait_for_k8s_agent [NAMESPACE] [LABEL_SELECTOR] [TIMEOUT_SECS]
wait_for_k8s_agent() {
    local ns="${1:-datadog}"
    local selector="${2:-app=datadog-agent}"
    local timeout="${3:-180}"
    local polls=$(( timeout / 10 ))
    echo "  Polling DaemonSet pods (up to ${timeout}s)..."
    local i _ready
    for i in $(seq 1 "$polls"); do
        _ready=$(kubectl get pods -n "$ns" -l "$selector" --no-headers 2>/dev/null \
            | grep -c "Running" || echo 0)
        if [[ "$_ready" -gt 0 ]]; then
            echo ""
            ok "Datadog Agent pods running ($_ready)"
            kubectl get pods -n "$ns" -l "$selector" --no-headers 2>/dev/null
            return 0
        fi
        printf "  ."
        sleep 10
    done
    echo ""
    warn "Agent pods not confirmed in ${timeout}s. Check: kubectl get pods -n $ns"
}

# ── .env helpers ──────────────────────────────────────────────────────────────
# ── keychain helpers ────────────────────────────────────────────────────────
# Credentials belong in the login keychain, not in a plaintext file. These are
# no-ops on a platform without the `security` CLI, and the caller then falls
# back to prompting.
_KC_SERVICE="learning-week-datadog"

_kc_get() {
    command -v security >/dev/null 2>&1 || return 0
    security find-generic-password -s "$_KC_SERVICE" -a "$1" -w 2>/dev/null || true
}

_kc_set() {
    if ! command -v security >/dev/null 2>&1; then
        warn "No login keychain here, so this key will not be remembered."
        return 0
    fi
    security add-generic-password -U -s "$_KC_SERVICE" -a "$1" -w "$2" \
        -D "Learning Week lab credential" >/dev/null 2>&1 \
        && ok "Stored $1 in the login keychain" \
        || warn "Could not write $1 to the login keychain"
}

_env_get() { grep -E "^$1=" "$ROOT_DIR/.env" | cut -d= -f2- | tr -d '"' || true; }

_env_set() {
    local key="$1" val="$2"
    python3 - "$ROOT_DIR/.env" "$key" "$val" <<'PY'
import re, sys
path, key, val = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path) as f:
    content = f.read()
pattern = rf'^{re.escape(key)}=.*$'
replacement = f'{key}={val}'
if re.search(pattern, content, re.MULTILINE):
    content = re.sub(pattern, replacement, content, flags=re.MULTILINE)
else:
    content = content.rstrip('\n') + f'\n{replacement}\n'
with open(path, 'w') as f:
    f.write(content)
PY
}

# ── Main bootstrap function ───────────────────────────────────────────────────
run_bootstrap() {
    # When called from setup_all.sh, bootstrap has already run once.
    # Skip straight to sourcing .env so day-specific env vars are available.
    if [[ "${SKIP_BOOTSTRAP:-0}" == "1" ]]; then
        _STEP=9
        [[ -f "$ROOT_DIR/.env" ]] && { set -a; source "$ROOT_DIR/.env"; set +a; }
        return 0
    fi

    local _os
    _os="$(uname -s)"

    # ── Linux pre-flight: ensure curl is present before any downloads ─────────
    # On macOS, curl is always bundled. On Linux, curl may be absent on
    # minimal images even if Docker is already installed.
    if [[ "$_os" == "Linux" ]] && ! command -v curl >/dev/null 2>&1; then
        warn "curl not found — installing..."
        if command -v apt-get >/dev/null 2>&1; then
            sudo apt-get update -qq && sudo apt-get install -y -q curl
        else
            sudo yum install -y curl
        fi
        ok "curl installed"
    fi

    # ── 1: Homebrew ───────────────────────────────────────────────────────────
    step "Homebrew"
    if [[ "$_os" == "Darwin" ]]; then
        if ! command -v brew >/dev/null 2>&1; then
            warn "Installing Homebrew..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            for _p in /opt/homebrew/bin/brew /usr/local/bin/brew; do
                [[ -x "$_p" ]] && eval "$("$_p" shellenv)" && break
            done
            ok "Homebrew installed"
        else
            ok "Homebrew $(brew --version | head -1)"
        fi
    else
        ok "Linux — skipping Homebrew"
    fi

    # ── 2: Docker ─────────────────────────────────────────────────────────────
    step "Docker"
    if ! command -v docker >/dev/null 2>&1; then
        if [[ "$_os" == "Darwin" ]]; then
            echo ""
            echo "  Choose a Docker runtime:"
            echo "  [1] Colima + docker CLI  (open source, recommended for labs)"
            echo "  [2] Docker Desktop       (official GUI — requires manual license acceptance)"
            echo ""
            read -r -p "  Choice [1/2, default 1]: " _dc
            _dc="${_dc:-1}"
            if [[ "$_dc" == "2" ]]; then
                brew install --cask docker
                open -a Docker
                echo ""
                read -r -p "  Press Enter when Docker Desktop shows 'Engine running': "
            else
                brew_install colima
                brew_install docker
                brew_install docker-compose
                colima status >/dev/null 2>&1 || colima start --cpu 4 --memory 8
            fi
        elif [[ "$_os" == "Linux" ]]; then
            command -v apt-get >/dev/null 2>&1 \
                || die "Auto-install not supported on this Linux. Install Docker manually: https://docs.docker.com/engine/install/"
            warn "Installing Docker Engine..."
            sudo apt-get update -qq
            sudo apt-get install -y -q ca-certificates curl gnupg
            sudo install -m 0755 -d /etc/apt/keyrings
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
                | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
            sudo chmod a+r /etc/apt/keyrings/docker.gpg
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
                | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
            sudo apt-get update -qq
            sudo apt-get install -y -q docker-ce docker-ce-cli containerd.io docker-compose-plugin
            sudo usermod -aG docker "$USER"
            warn "Added $USER to docker group. You may need to log out and back in."
        else
            die "Unsupported OS: $_os"
        fi
    fi

    if ! docker info >/dev/null 2>&1; then
        warn "Docker installed but not running."
        if [[ "$_os" == "Darwin" ]]; then
            if command -v colima >/dev/null 2>&1 && ! colima status >/dev/null 2>&1; then
                warn "Starting Colima..."
                colima start --cpu 4 --memory 8
            else
                read -r -p "  Open Docker Desktop and press Enter when running: "
            fi
        elif [[ "$_os" == "Linux" ]]; then
            sudo systemctl start docker
        fi
        docker info >/dev/null 2>&1 || die "Docker still not running. Fix it and re-run."
    fi
    ok "Docker $(docker version --format '{{.Server.Version}}' 2>/dev/null || echo 'running')"

    # Ensure docker compose v2 plugin works — required by all days.
    # brew install docker-compose installs as a CLI plugin, but only if
    # the plugin dir is in Docker's search path. Verify explicitly.
    if ! docker compose version >/dev/null 2>&1; then
        warn "'docker compose' plugin not available. Installing..."
        if [[ "$_os" == "Darwin" ]]; then
            brew_install docker-compose
        elif [[ "$_os" == "Linux" ]]; then
            if command -v apt-get >/dev/null 2>&1; then
                sudo apt-get install -y -q docker-compose-plugin
            else
                warn "Could not auto-install docker-compose-plugin. Run: sudo yum install docker-compose-plugin"
            fi
        fi
        docker compose version >/dev/null 2>&1 \
            || die "'docker compose' still not working after install attempt. Fix it and re-run."
        ok "docker compose plugin installed"
    fi

    # ── 3: Python 3 ───────────────────────────────────────────────────────────
    step "Python 3"
    if command -v python3 >/dev/null 2>&1; then
        ok "Python $(python3 --version)"
    else
        case "$_os" in
            Darwin) brew_install python3 ;;
            Linux)
                command -v apt-get >/dev/null 2>&1 && apt_install python3 || sudo yum install -y python3 ;;
        esac
    fi

    # ── 4: jq ─────────────────────────────────────────────────────────────────
    step "jq"
    if command -v jq >/dev/null 2>&1; then
        ok "jq $(jq --version)"
    else
        case "$_os" in
            Darwin) brew_install jq ;;
            Linux)
                command -v apt-get >/dev/null 2>&1 && apt_install jq || sudo yum install -y jq ;;
        esac
    fi

    # ── 5: kubectl ────────────────────────────────────────────────────────────
    step "kubectl"
    if command -v kubectl >/dev/null 2>&1; then
        ok "kubectl $(kubectl version --client --output=yaml 2>/dev/null | grep gitVersion | head -1 | awk '{print $2}' || echo 'installed')"
    else
        case "$_os" in
            Darwin) brew_install kubectl ;;
            Linux)
                local _kv
                _kv="$(curl -sL https://dl.k8s.io/release/stable.txt)"
                curl -sLO "https://dl.k8s.io/release/${_kv}/bin/linux/amd64/kubectl"
                sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl && rm kubectl
                ok "kubectl ${_kv}"
                ;;
        esac
    fi

    # ── 6: minikube ───────────────────────────────────────────────────────────
    step "minikube"
    if command -v minikube >/dev/null 2>&1; then
        ok "minikube $(minikube version --short 2>/dev/null | head -1 || echo 'installed')"
    else
        case "$_os" in
            Darwin) brew_install minikube ;;
            Linux)
                curl -sLO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
                sudo install minikube-linux-amd64 /usr/local/bin/minikube && rm minikube-linux-amd64
                ok "minikube installed"
                ;;
        esac
    fi

    # ── 7: kind ───────────────────────────────────────────────────────────────
    step "kind"
    if command -v kind >/dev/null 2>&1; then
        ok "kind $(kind version 2>/dev/null | awk '{print $2}' || echo 'installed')"
    else
        case "$_os" in
            Darwin) brew_install kind ;;
            Linux)
                curl -sLo kind "https://kind.sigs.k8s.io/dl/v0.23.0/kind-linux-amd64"
                chmod +x kind && sudo mv kind /usr/local/bin/kind
                ok "kind v0.23.0"
                ;;
        esac
    fi

    # ── 8: Helm ───────────────────────────────────────────────────────────────
    step "Helm"
    if command -v helm >/dev/null 2>&1; then
        ok "Helm $(helm version --short 2>/dev/null | head -1 || echo 'installed')"
    else
        case "$_os" in
            Darwin) brew_install helm ;;
            Linux)  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash ;;
        esac
    fi

    # ── 9: .env ───────────────────────────────────────────────────────────────
    step ".env configuration"
    [[ -f "$ROOT_DIR/.env" ]] || cp "$ROOT_DIR/.env.example" "$ROOT_DIR/.env"

    local _api _app _site
    # Keys come from the environment first: the control panel injects them from
    # the login keychain. .env deliberately no longer holds them.
    _api="${DD_API_KEY:-$(_kc_get DD_API_KEY)}"
    _app="${DD_APP_KEY:-$(_kc_get DD_APP_KEY)}"
    _site="$(_env_get DD_SITE)"; _site="${_site:-datadoghq.com}"

    if [[ -z "$_api" || "$_api" == "your_api_key_here" ]]; then
        if [[ ! -t 0 ]]; then
            die "No Datadog API key available. Add it in the control panel (./start-ui.sh), which stores it in the login keychain."
        fi
        echo ""
        echo "  Get your API key: https://app.${_site}/organization-settings/api-keys"
        read -r -s -p "  Datadog API Key: " _api; echo ""
        _kc_set "DD_API_KEY" "$_api"
    fi

    if [[ -z "$_app" || "$_app" == "your_app_key_here" ]]; then
        if [[ ! -t 0 ]]; then
            die "No Datadog application key available. Add it in the control panel (./start-ui.sh), which stores it in the login keychain."
        fi
        echo ""
        echo "  Get your APP key: https://app.${_site}/organization-settings/application-keys"
        read -r -s -p "  Datadog APP Key: " _app; echo ""
        _kc_set "DD_APP_KEY" "$_app"
    fi

    export DD_API_KEY="$_api" DD_APP_KEY="$_app" DD_SITE="$_site"

    warn "Validating API keys..."
    local _vr
    _vr=$(python3 - "$_api" "$_app" "$_site" <<'PY'
import json, sys, urllib.request
api, app, site = sys.argv[1], sys.argv[2], sys.argv[3]
req = urllib.request.Request(
    f"https://api.{site}/api/v1/validate",
    headers={"DD-API-KEY": api, "DD-APPLICATION-KEY": app}
)
try:
    with urllib.request.urlopen(req, timeout=10) as r:
        data = json.loads(r.read().decode())
    print("ok" if data.get("valid") else "invalid")
except Exception as e:
    print(f"error:{e}")
PY
)
    case "$_vr" in
        ok)      ok "API keys valid (site: ${_site})" ;;
        invalid) die "API keys rejected by ${_site}. Fix them in the control panel (./start-ui.sh), which stores them in the login keychain." ;;
        # An error here used to be a warning, and the setup carried on to print
        # success with zero monitors created. A key we cannot validate is a key
        # we cannot use, so stop.
        *)       die "Could not validate the Datadog keys against ${_site} (${_vr}). Check the site setting and your network, then try again." ;;
    esac

    set -a; source "$ROOT_DIR/.env"; set +a
}

_LW_BOOTSTRAP_LOADED=1
