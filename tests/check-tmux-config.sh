#!/usr/bin/env bash
# tests/check-tmux-config.sh — workbench-shell, workbench-core D110.
#
# The tmux layer (files/tmux.conf) is included at the TOP of the user's own
# tmux config, so it must hold plain settings and plugin option defaults only.
# The plugins and TPM live in files/tmux-plugins.conf, which the user opts into
# by sourcing it as the LAST line of their own config: TPM reads the plugin
# list and the plugin options when it runs, so it has to come after everything
# else. tmux-continuum's boot autostart is off by default.
#
# The structural checks need nothing installed. When tmux is on PATH the layer
# file is also loaded by a real tmux server on a private socket, with a fake
# HOME, to prove it parses and sets the options. Plain bash, numbered
# OK:/FAIL: checks, no framework. SKIP: only when tmux is absent.
#
# SC2015: '[[ cond ]] && ok || fail' is this suite's assertion idiom.
# shellcheck disable=SC2015
set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." >/dev/null 2>&1 && pwd)"
LAYER="${REPO_ROOT}/files/tmux.conf"
PLUGINS="${REPO_ROOT}/files/tmux-plugins.conf"

FAILED=0
check_no=0
ok()   { check_no=$((check_no + 1)); echo "OK:   [$check_no] $*"; }
fail() { check_no=$((check_no + 1)); echo "FAIL: [$check_no] $*"; FAILED=$((FAILED + 1)); }

# code_lines <file> — the lines that are not blank and not comments.
code_lines() { grep -vE '^[[:space:]]*(#|$)' "$1"; }

# ── The layer file: settings and option defaults only. ──────────────────────
if code_lines "${LAYER}" | grep -qE "@plugin|^[[:space:]]*run|git clone|tpm"; then
    fail "files/tmux.conf declares a plugin, runs something or mentions TPM in code:"
    code_lines "${LAYER}" | grep -E "@plugin|^[[:space:]]*run|git clone|tpm"
else
    ok "files/tmux.conf declares no plugins and starts nothing"
fi

boot="$(code_lines "${LAYER}" | grep -E "@continuum-boot" || true)"
[[ "${boot}" == "set -g @continuum-boot 'off'" ]] \
    && ok "files/tmux.conf sets @continuum-boot to 'off'" \
    || fail "@continuum-boot in the layer file is: '${boot}'"

if grep -rEn "@continuum-boot 'on'" "${LAYER}" "${PLUGINS}" | grep -vE '^[^:]+:[0-9]+:[[:space:]]*#' >/dev/null; then
    fail "something sets @continuum-boot to 'on'"
else
    ok "nothing in the module turns the boot autostart on"
fi

# ── The plugins file: plugins, bootstrap, and TPM's run line LAST. ──────────
last="$(code_lines "${PLUGINS}" | tail -1)"
[[ "${last}" == "run -b '~/.tmux/plugins/tpm/tpm'" ]] \
    && ok "files/tmux-plugins.conf ends with TPM's run line" \
    || fail "the last line of code in tmux-plugins.conf is: '${last}'"

n_plugins="$(code_lines "${PLUGINS}" | grep -c "^set -g @plugin ")"
[[ "${n_plugins}" -eq 8 ]] \
    && ok "files/tmux-plugins.conf declares the eight plugins the module always did" \
    || fail "expected 8 @plugin lines, found ${n_plugins}"

# ── Only the settings file is layered into the user's config. ───────────────
if grep -E '^[[:space:]]*src:' "${REPO_ROOT}/workbench.yml" | grep -q 'tmux-plugins.conf'; then
    fail "workbench.yml layers tmux-plugins.conf; it must stay opt-in"
else
    ok "workbench.yml does not layer tmux-plugins.conf"
fi

# ── With a real tmux: the layer file parses and sets what it says. ──────────
if ! command -v tmux >/dev/null 2>&1; then
    echo "SKIP: tmux is not installed — the load checks need it"
else
    WORK="$(mktemp -d "${TMPDIR:-/tmp}/wb-tmux-config.XXXXXX")"
    trap 'rm -rf "${WORK}"' EXIT
    mkdir -p "${WORK}/home"
    # One socket per server. Starting a second server on the socket a first
    # one has just been killed on can fail with "server exited unexpectedly"
    # while the old one is still shutting down.
    SOCK="wb-test-$$-a"
    run_tmux() { HOME="${WORK}/home" TMUX_TMPDIR="${WORK}" TERM=xterm tmux -L "${SOCK}" "$@"; }

    err="$(run_tmux -f "${LAYER}" new-session -d -s t 'sleep 30' 2>&1)"
    if [[ -z "${err}" ]]; then
        ok "tmux loads files/tmux.conf without an error"
    else
        fail "tmux reported: ${err}"
    fi
    [[ "$(run_tmux show-options -gv @continuum-boot 2>&1)" == "off" ]] \
        && ok "the running tmux has @continuum-boot off" \
        || fail "@continuum-boot in the running tmux: $(run_tmux show-options -gv @continuum-boot 2>&1)"
    [[ "$(run_tmux show-options -gv mouse 2>&1)" == "on" ]] \
        && ok "...and the plain settings applied (mouse on)" \
        || fail "mouse is: $(run_tmux show-options -gv mouse 2>&1)"
    run_tmux kill-server 2>/dev/null

    # The plugin declarations parse too, without running TPM or cloning.
    SOCK="wb-test-$$-b"
    sed -e '/^if "test/,$d' "${PLUGINS}" > "${WORK}/declarations.conf"
    err="$(run_tmux -f "${WORK}/declarations.conf" new-session -d -s t 'sleep 30' 2>&1)"
    [[ -z "${err}" ]] \
        && ok "tmux parses the plugin declarations in tmux-plugins.conf" \
        || fail "tmux reported on the plugin declarations: ${err}"
    run_tmux kill-server 2>/dev/null
fi

echo
if [[ "${FAILED}" -eq 0 ]]; then
    echo "All ${check_no} checks passed."
    exit 0
else
    echo "${FAILED} of ${check_no} checks failed."
    exit 1
fi
