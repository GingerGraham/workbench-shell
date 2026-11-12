#!/usr/bin/env bash
# tests/check-neovim-package-guard.sh — workbench-shell, workbench-core D110.
#
# install-neovim installs a tarball and then offers to remove the packaged
# Neovim. It must not offer to remove a package that something else on the
# host depends on: it says why in one line and leaves it. Stub package
# managers on PATH print what the real ones print, in outline, for a package
# that has dependents and one that has none. No network.
# Plain bash, numbered OK:/FAIL: checks, no framework.
#
# SC2015: '[[ cond ]] && ok || fail' is this suite's assertion idiom.
# SC2317: stubs are called by the sourced installer, not directly.
# SC2016: the stub bodies are written to files and run later.
# shellcheck disable=SC2015,SC2016,SC2317
set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." >/dev/null 2>&1 && pwd)"

FAILED=0
check_no=0
ok()   { check_no=$((check_no + 1)); echo "OK:   [$check_no] $*"; }
fail() { check_no=$((check_no + 1)); echo "FAIL: [$check_no] $*"; FAILED=$((FAILED + 1)); }

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
export HOME="${WORK}/home"
mkdir -p "${HOME}" "${WORK}/bin"
WARNINGS="${WORK}/warnings"
PROMPTED="${WORK}/prompted"

# Core API stand-ins.
log_info()  { :; }
log_warn()  { echo "$*" >> "${WARNINGS}"; }
log_error() { :; }
log_debug() { :; }
get-elevation-command() { echo "elevate"; }
_str_lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }
# The prompt: record that it was asked, and answer "no" so nothing is removed.
_read_prompt() { echo asked >> "${PROMPTED}"; eval "$2=n"; }

# shellcheck source=shell/installers.sh
source "${REPO_ROOT}/shell/installers.sh"

# stub <name> <script body> — an executable on the stub PATH.
stub() {
    printf '#!/usr/bin/env bash\n%s\n' "$2" > "${WORK}/bin/$1"
    chmod +x "${WORK}/bin/$1"
}
reset_stubs() { rm -f "${WORK}/bin/"*; : > "${WARNINGS}"; rm -f "${PROMPTED}"; }

# run_cleanup <distro> [path-tail] — the whole cleanup function, on a Linux
# host of that family with the stub package managers first on PATH and
# <path-tail> (default: the system directories) after them.
run_cleanup() {
    (
        WORKBENCH_OS=Linux
        WORKBENCH_DISTRO="$1"
        PATH="${WORK}/bin:${2:-/usr/bin:/bin}"
        _neovim_cleanup_package_install
    )
}

# ── Arch: pacman -Qi "Required By" ──────────────────────────────────────────
reset_stubs
stub pacman 'case "$1" in
    -Q) echo "neovim 0.10.0-1" ;;
    -Qi) printf "Name            : neovim\nRequired By     : neovim-qt\n                  nvim-helper\nOptional For    : None\n" ;;
esac'
run_cleanup arch
grep -q "neovim-qt nvim-helper depend on it" "${WARNINGS}" && [[ ! -e "${PROMPTED}" ]] \
    && ok "arch: a package with dependents (wrapped over two lines) is not offered for removal, and the reason is one line" \
    || { fail "arch with dependents: $(cat "${WARNINGS}") prompted=$([[ -e ${PROMPTED} ]] && echo yes || echo no)"; }

reset_stubs
stub pacman 'case "$1" in
    -Q) echo "neovim 0.10.0-1" ;;
    -Qi) printf "Name            : neovim\nRequired By     : None\nOptional For    : None\n" ;;
esac'
run_cleanup arch
! grep -q "Not offering" "${WARNINGS}" && [[ -e "${PROMPTED}" ]] \
    && ok "arch: Required By None: the removal offer is made as before" \
    || fail "arch with no dependents: $(cat "${WARNINGS}") prompted=$([[ -e ${PROMPTED} ]] && echo yes || echo no)"

# ── rpm families ────────────────────────────────────────────────────────────
reset_stubs
stub rpm 'case "$*" in
    "-q neovim") echo "neovim-0.10.0-1.fc41.x86_64" ;;
    "-q --whatrequires neovim") echo "neovim-qt-1.0-1.fc41.x86_64" ;;
esac'
run_cleanup rhel
grep -q "neovim-qt-1.0-1.fc41.x86_64 depend on it" "${WARNINGS}" && [[ ! -e "${PROMPTED}" ]] \
    && ok "rhel: a package with dependents is not offered for removal" \
    || fail "rhel with dependents: $(cat "${WARNINGS}")"

reset_stubs
stub rpm 'case "$*" in
    "-q neovim") echo "neovim-0.10.0-1.fc41.x86_64" ;;
    "-q --whatrequires neovim") echo "no package requires neovim"; exit 1 ;;
esac'
run_cleanup rhel
! grep -q "Not offering" "${WARNINGS}" && [[ -e "${PROMPTED}" ]] \
    && ok "rhel: 'no package requires neovim': the removal offer is made as before" \
    || fail "rhel with no dependents: $(cat "${WARNINGS}")"

# ── Debian family ───────────────────────────────────────────────────────────
reset_stubs
stub dpkg 'printf "Package: neovim\nVersion: 0.9.5-1\n"'
stub apt-cache 'printf "neovim\nReverse Depends:\n  neovim-qt\n |vim-alt\n"'
run_cleanup debian
grep -q "neovim-qt vim-alt depend on it" "${WARNINGS}" && [[ ! -e "${PROMPTED}" ]] \
    && ok "debian: a package with dependents is not offered for removal" \
    || fail "debian with dependents: $(cat "${WARNINGS}")"

reset_stubs
stub dpkg 'printf "Package: neovim\nVersion: 0.9.5-1\n"'
stub apt-cache 'printf "neovim\nReverse Depends:\n"'
run_cleanup debian
! grep -q "Not offering" "${WARNINGS}" && [[ -e "${PROMPTED}" ]] \
    && ok "debian: no reverse dependencies: the removal offer is made as before" \
    || fail "debian with no dependents: $(cat "${WARNINGS}")"

# ── A host whose package manager cannot be asked behaves as before. ────────
reset_stubs
stub dpkg 'printf "Package: neovim\nVersion: 0.9.5-1\n"'
# Only the tools the function and the stubs use (bash, for their shebang), so a real apt-cache on this
# machine cannot answer.
mkdir -p "${WORK}/tools"
for tool in tr awk bash; do ln -sf "$(command -v "${tool}")" "${WORK}/tools/${tool}"; done
run_cleanup debian "${WORK}/tools"
! grep -q "Not offering" "${WARNINGS}" && [[ -e "${PROMPTED}" ]] \
    && ok "debian without apt-cache: the check is skipped and the offer is made as before" \
    || fail "debian without apt-cache: $(cat "${WARNINGS}")"

echo
if [[ "${FAILED}" -eq 0 ]]; then
    echo "All ${check_no} checks passed."
    exit 0
else
    echo "${FAILED} of ${check_no} checks failed."
    exit 1
fi
