#!/usr/bin/env bash
# tests/check-pacman-failure.sh — workbench-shell, workbench-core D110.
#
# Some hosts put a guard around pacman that refuses a direct install. The
# installers must not try to get round it, and must not report success when
# pacman fails: the failure is returned and pacman's own message reaches the
# user. A stub pacman prints a guard-style refusal on stderr and exits 1.
# Plain bash, numbered OK:/FAIL: checks, no framework.
#
# SC2015: '[[ cond ]] && ok || fail' is this suite's assertion idiom.
# SC2317: stubs are called by the sourced installer, not directly.
# shellcheck disable=SC2015,SC2317
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
mkdir -p "${HOME}" "${WORK}/bin" "${WORK}/tools"

# Only what the installers and the stubs need, so no real zsh or pacman on
# this machine answers.
for tool in env bash tr awk sed grep cat rm; do ln -sf "$(command -v "${tool}")" "${WORK}/tools/${tool}"; done
printf '#!/usr/bin/env bash\necho "error: direct installs are blocked on this host (guard)" >&2\nexit 1\n' > "${WORK}/bin/pacman"
chmod +x "${WORK}/bin/pacman"

log_info()  { :; }
log_warn()  { :; }
log_error() { echo "ERROR: $*" >&2; }
log_debug() { :; }
get-elevation-command() { echo "env"; }

# shellcheck source=shell/installers.sh
source "${REPO_ROOT}/shell/installers.sh"

WORKBENCH_OS=Linux
WORKBENCH_DISTRO=arch
export PATH="${WORK}/bin:${WORK}/tools"

# check_fails <label> <function>
check_fails() {
    local label="$1" fn="$2" out rc
    out="$("${fn}" 2>&1)"; rc=$?
    [[ "${rc}" -ne 0 && "${out}" == *"direct installs are blocked on this host (guard)"* ]] \
        && ok "${label}: returns ${rc} and pacman's message reaches the user" \
        || fail "${label}: rc=${rc} output='${out}'"
}

check_fails "install-zsh"                 install-zsh
check_fails "zsh plugins (pacman route)"  _zsh-plugins-install-packages-pacman
check_fails "direnv (pacman route)"       _direnv-install-arch
check_fails "fzf (pacman route)"          _fzf-install-arch

# No bypass is attempted: nothing in the installers sets a guard-bypass
# variable or calls pacman by absolute path.
if grep -nE 'ALLOW_DIRECT|/usr/bin/pacman|command pacman' "${REPO_ROOT}/shell/installers.sh" >/dev/null; then
    fail "installers.sh contains something that looks like a guard bypass"
else
    ok "no guard bypass in shell/installers.sh"
fi

echo
if [[ "${FAILED}" -eq 0 ]]; then
    echo "All ${check_no} checks passed."
    exit 0
else
    echo "${FAILED} of ${check_no} checks failed."
    exit 1
fi
