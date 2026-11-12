#!/usr/bin/env bash
# tests/check-neovim-skip.sh — workbench-shell, workbench-core D110.
#
# install-neovim installs the upstream tarball, and used to do so even when
# the host already had a Neovim (a package, mise, Homebrew), leaving a second
# copy that either shadowed it or, where ~/.local/bin comes later on PATH,
# was never used. It now returns at once when the nvim on PATH is not the one
# it installed itself, and still installs and upgrades its own. A stub curl
# records whether any download was attempted.
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

WORK="$(mktemp -d "${TMPDIR:-/tmp}/wb-neovim-skip.XXXXXX")"
trap 'rm -rf "${WORK}"' EXIT
export HOME="${WORK}/home"
mkdir -p "${HOME}/.local/bin" "${WORK}/tools" "${WORK}/host-bin"
CALLS="${WORK}/curl-calls"
MESSAGES="${WORK}/messages"

# Only what install-neovim needs before it reaches the network, so no nvim
# on this machine can answer.
for tool in env bash tar readlink sed tr awk cat; do ln -sf "$(command -v "${tool}")" "${WORK}/tools/${tool}"; done
printf '#!/usr/bin/env bash\necho call >> "%s"\nexit 22\n' "${CALLS}" > "${WORK}/tools/curl"
chmod +x "${WORK}/tools/curl"

log_info()  { echo "$*" >> "${MESSAGES}"; }
log_warn()  { echo "$*" >> "${MESSAGES}"; }
log_error() { echo "$*" >> "${MESSAGES}"; }
log_debug() { :; }

# shellcheck source=shell/installers.sh
source "${REPO_ROOT}/shell/installers.sh"

# run_install <PATH> — install-neovim in a subshell with that PATH; prints
# its return code. Resets the call and message logs first.
run_install() {
    : > "${CALLS}"; : > "${MESSAGES}"
    ( PATH="$1"; install-neovim >/dev/null 2>&1; echo $? )
}
calls() { wc -l < "${CALLS}" | tr -d ' '; }

# 1. A Neovim from the host (a package, say) is on PATH: nothing is downloaded.
printf '#!/usr/bin/env bash\nexit 0\n' > "${WORK}/host-bin/nvim"; chmod +x "${WORK}/host-bin/nvim"
rc="$(run_install "${WORK}/host-bin:${WORK}/tools")"
[[ "${rc}" -eq 0 && "$(calls)" -eq 0 ]] \
    && ok "a host nvim on PATH: returns 0 and attempts no download" \
    || fail "host nvim: rc=${rc} curl calls=$(calls)"
grep -q "already installed (${WORK}/host-bin/nvim)" "${MESSAGES}" \
    && ok "...and says which nvim it found" \
    || fail "message was: $(cat "${MESSAGES}")"

# 2. No nvim anywhere: the install goes ahead (here it stops at the stub
#    curl failing, which is after the download was attempted).
rm -f "${WORK}/host-bin/nvim"
rc="$(run_install "${WORK}/tools")"
[[ "${rc}" -ne 0 && "$(calls)" -ge 1 ]] \
    && ok "no nvim on PATH: the install proceeds to the download" \
    || fail "no nvim: rc=${rc} curl calls=$(calls)"

# 3. The nvim on PATH is this installer's own symlink: install and upgrade
#    still go ahead.
mkdir -p "${HOME}/.local/opt/nvim-v0.9.5/bin"
printf '#!/usr/bin/env bash\nexit 0\n' > "${HOME}/.local/opt/nvim-v0.9.5/bin/nvim"; chmod +x "${HOME}/.local/opt/nvim-v0.9.5/bin/nvim"
ln -sfn "${HOME}/.local/opt/nvim-v0.9.5/bin/nvim" "${HOME}/.local/bin/nvim"
rc="$(run_install "${HOME}/.local/bin:${WORK}/tools")"
[[ "$(calls)" -ge 1 ]] \
    && ok "workbench's own nvim symlink on PATH: the upgrade path still runs" \
    || fail "own symlink: rc=${rc} curl calls=$(calls); $(cat "${MESSAGES}")"

# 4. Our symlink exists but a host nvim comes first on PATH: the host's is
#    the one that runs, so nothing is installed.
printf '#!/usr/bin/env bash\nexit 0\n' > "${WORK}/host-bin/nvim"; chmod +x "${WORK}/host-bin/nvim"
rc="$(run_install "${WORK}/host-bin:${HOME}/.local/bin:${WORK}/tools")"
[[ "${rc}" -eq 0 && "$(calls)" -eq 0 ]] \
    && ok "a host nvim ahead of ours on PATH: skipped" \
    || fail "host nvim ahead of ours: rc=${rc} curl calls=$(calls)"

# 5. A regular file at ~/.local/bin/nvim that is not our symlink counts as
#    someone else's.
rm -f "${HOME}/.local/bin/nvim"
printf '#!/usr/bin/env bash\nexit 0\n' > "${HOME}/.local/bin/nvim"; chmod +x "${HOME}/.local/bin/nvim"
rc="$(run_install "${HOME}/.local/bin:${WORK}/tools")"
[[ "${rc}" -eq 0 && "$(calls)" -eq 0 ]] \
    && ok "a ~/.local/bin/nvim that is not our symlink: left alone" \
    || fail "foreign ~/.local/bin/nvim: rc=${rc} curl calls=$(calls)"

echo
if [[ "${FAILED}" -eq 0 ]]; then
    echo "All ${check_no} checks passed."
    exit 0
else
    echo "${FAILED} of ${check_no} checks failed."
    exit 1
fi
