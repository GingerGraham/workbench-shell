#!/usr/bin/env bash
# tests/check-fzf-install-floor.sh — workbench-shell
# install-fzf (shell/installers.sh) installs from the distro first, but
# shell integration needs fzf 0.48.0+ (`fzf --bash` / `--zsh`). When the
# distro package is older, or the fzf already first on PATH is the upstream
# binary this function placed in ~/.local/bin, install-fzf takes the
# upstream-release path (_fzf-install-binary) instead — and fails loudly if
# a too-old fzf still wins on PATH afterwards.
#
# The per-distro installers and _fzf-install-binary are stubbed to record
# that they ran and to put a stub fzf executable where the real one would
# land, in a temp HOME and temp PATH directories. No network.
# Plain bash, numbered OK:/FAIL: checks, no framework.
#
# SC2015: '[[ cond ]] && ok || fail' is this suite's assertion idiom.
# SC2317: stubs are called by the sourced installer, not directly.
# shellcheck disable=SC2015,SC2317
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

FAILED=0
check_no=0
ok()   { check_no=$((check_no + 1)); echo "OK:   [$check_no] $*"; }
fail() { check_no=$((check_no + 1)); echo "FAIL: [$check_no] $*"; FAILED=$((FAILED + 1)); }

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
export HOME="${WORK}/home"
DISTRO_BIN="${WORK}/usr-bin"          # where the distro package puts fzf
LOCAL_BIN="${HOME}/.local/bin"        # where the upstream binary goes
CALL_LOG="${WORK}/calls"

# ── Stubs standing in for workbench-core's Core API ─────────────────────────
log_info()  { :; }
log_warn()  { echo "WARN: $*" >> "${WORK}/warnings"; }
log_error() { :; }
log_debug() { :; }
get-elevation-command() { return 1; }

# shellcheck source=shell/installers.sh
source "${REPO_ROOT}/shell/installers.sh"

# make_fzf <dir> <raw --version output>
make_fzf() {
    mkdir -p "$1"
    printf '#!/bin/sh\necho "%s"\n' "$2" > "$1/fzf"
    chmod +x "$1/fzf"
}

# Per-distro installers: record the call and, when DISTRO_RESULT_VERSION is
# set, put an fzf of that version in the distro directory (as the package
# manager would); when unset, fail without installing anything.
distro_install() {
    echo "distro:$1" >> "${CALL_LOG}"
    [[ -n "${DISTRO_RESULT_VERSION:-}" ]] || return 1
    make_fzf "${DISTRO_BIN}" "${DISTRO_RESULT_VERSION}"
}
_fzf-install-rhel()   { distro_install rhel; }
_fzf-install-debian() { distro_install debian; }
_fzf-install-suse()   { distro_install suse; }
_fzf-install-arch()   { distro_install arch; }
# The upstream release: records the call and lands a current fzf in
# ~/.local/bin. BINARY_FAILS=1 simulates a download that fails.
_fzf-install-binary() {
    echo "binary" >> "${CALL_LOG}"
    [[ "${BINARY_FAILS:-0}" -eq 0 ]] || return 1
    make_fzf "${LOCAL_BIN}" "0.55.0 (upstream)"
}

# run_install <distro> <PATH>
# Runs install-fzf in a subshell so the stubs' environment is fresh each
# time; the return code is install-fzf's.
run_install() {
    (
        WORKBENCH_OS="Linux"
        WORKBENCH_DISTRO="$1"
        PATH="$2"
        install-fzf >/dev/null 2>&1
    )
}

# reset: empty both bin directories, the call log and the warnings.
reset() {
    rm -rf "${DISTRO_BIN}" "${LOCAL_BIN}" "${WORK}/warnings"
    mkdir -p "${DISTRO_BIN}" "${LOCAL_BIN}"
    : > "${CALL_LOG}"
    unset DISTRO_RESULT_VERSION BINARY_FAILS
}
binary_called() { grep -q '^binary$' "${CALL_LOG}"; }
distro_called() { grep -q '^distro:' "${CALL_LOG}"; }

# ~/.local/bin ahead of the distro directory, as workbench-core's loader
# arranges. /usr/bin and /bin stay on the path for the commands install-fzf
# itself uses.
GOOD_PATH="${LOCAL_BIN}:${DISTRO_BIN}:/usr/bin:/bin"

# ── Installed-version parsing ────────────────────────────────────────────────
reset
make_fzf "${DISTRO_BIN}" "0.44.1 (debian)"
[[ "$(PATH="${DISTRO_BIN}:/usr/bin:/bin" _fzf-installed-version)" == "0.44.1" ]] \
    && ok "version parsing: '0.44.1 (debian)' -> 0.44.1" \
    || fail "version parsing, distro suffix: '$(PATH="${DISTRO_BIN}:/usr/bin:/bin" _fzf-installed-version)'"
make_fzf "${DISTRO_BIN}" "0.48.0-dev"
[[ "$(PATH="${DISTRO_BIN}:/usr/bin:/bin" _fzf-installed-version)" == "0.48.0" ]] \
    && ok "version parsing: '0.48.0-dev' -> 0.48.0" \
    || fail "version parsing, -dev suffix: '$(PATH="${DISTRO_BIN}:/usr/bin:/bin" _fzf-installed-version)'"
make_fzf "${DISTRO_BIN}" ""
_fzf-version-ge "$(PATH="${DISTRO_BIN}:/usr/bin:/bin" _fzf-installed-version)" "$(_fzf-min-version)" \
    && fail "version parsing: empty output counted as satisfying the floor" \
    || ok "version parsing: empty output does not satisfy the floor"
make_fzf "${DISTRO_BIN}" "not a version"
_fzf-version-ge "$(PATH="${DISTRO_BIN}:/usr/bin:/bin" _fzf-installed-version)" "$(_fzf-min-version)" \
    && fail "version parsing: garbage counted as satisfying the floor" \
    || ok "version parsing: garbage does not satisfy the floor"
rm -rf "${DISTRO_BIN}"
[[ -z "$(PATH="${DISTRO_BIN}:/usr/bin:/bin" _fzf-installed-version)" ]] \
    && ok "version parsing: no fzf on PATH prints nothing" \
    || fail "version parsing, no fzf: '$(PATH="${DISTRO_BIN}:/usr/bin:/bin" _fzf-installed-version)'"

# ── Version comparison ───────────────────────────────────────────────────────
# version_ge_case <have> <need> <expected: yes|no>
version_ge_case() {
    local got="no"
    _fzf-version-ge "$1" "$2" && got="yes"
    [[ "${got}" == "$3" ]] \
        && ok "compare: '$1' >= '$2' is $3" \
        || fail "compare: '$1' >= '$2' expected $3, got ${got}"
}
[[ "$(_fzf-min-version)" == "0.48.0" ]] \
    && ok "the floor is 0.48.0" \
    || fail "the floor is '$(_fzf-min-version)'"
version_ge_case 0.9.0   0.48.0 no     # numeric, not lexicographic
version_ge_case 0.44.1  0.48.0 no
version_ge_case 0.47.9  0.48.0 no
version_ge_case 0.48.0  0.48.0 yes
version_ge_case 0.48.1  0.48.0 yes
version_ge_case 0.100.0 0.48.0 yes    # 100 > 48, though "100" < "48" as text
version_ge_case 1.0.0   0.48.0 yes
version_ge_case 0.48    0.48.0 yes    # a missing segment counts as 0
version_ge_case 0.08.0  0.8.0  yes    # a leading zero is not octal
version_ge_case ""      0.48.0 no
version_ge_case abc     0.48.0 no
version_ge_case 0..1    0.48.0 no
version_ge_case 0.48.0. 0.48.0 no

# The same comparison under zsh, where `read -a` and 0-based array indexing
# do not exist: the function is lifted out of installers.sh and run there.
if command -v zsh &>/dev/null; then
    zsh_cases="0.9.0 0.48.0 no|0.44.1 0.48.0 no|0.48.0 0.48.0 yes|0.48.1 0.48.0 yes|0.100.0 0.48.0 yes|0.48 0.48.0 yes|0.08.0 0.8.0 yes|abc 0.48.0 no|0..1 0.48.0 no"
    zsh_got="$(zsh -c "$(sed -n '/^_fzf-version-ge() {/,/^}/p' "${REPO_ROOT}/shell/installers.sh")
        for c in \${(s:|:)1}; do
            set -- \${=c}
            r=no; _fzf-version-ge \"\$1\" \"\$2\" && r=yes
            [[ \"\$r\" == \"\$3\" ]] || echo \"MISMATCH \$c (got \$r)\"
        done" -- "${zsh_cases}" 2>&1)"
    [[ -z "${zsh_got}" ]] \
        && ok "zsh: _fzf-version-ge gives the same answers as in bash" \
        || fail "zsh: _fzf-version-ge: ${zsh_got}"
else
    echo "SKIP: zsh not installed — zsh comparison check skipped"
fi

# ── install-fzf ──────────────────────────────────────────────────────────────
# Distro package too old (the Pop!_OS case): upstream release is installed.
reset
DISTRO_RESULT_VERSION="0.44.1 (debian)"
run_install debian "${GOOD_PATH}"; rc=$?
binary_called && [[ "${rc}" -eq 0 && -x "${LOCAL_BIN}/fzf" ]] \
    && ok "debian, distro fzf 0.44.1: upstream binary installed, install-fzf succeeds" \
    || fail "debian 0.44.1: rc=${rc} calls: $(tr '\n' ' ' < "${CALL_LOG}")"
grep -q 'older than 0.48.0' "${WORK}/warnings" 2>/dev/null \
    && ok "debian, distro fzf 0.44.1: the fallback is announced" \
    || fail "debian 0.44.1: no fallback warning: $(cat "${WORK}/warnings" 2>/dev/null)"

# Distro package current: nothing from upstream.
reset
DISTRO_RESULT_VERSION="0.50.0 (debian)"
run_install debian "${GOOD_PATH}"; rc=$?
! binary_called && [[ "${rc}" -eq 0 && ! -e "${LOCAL_BIN}/fzf" ]] \
    && ok "debian, distro fzf 0.50.0: no upstream binary, nothing in ~/.local/bin" \
    || fail "debian 0.50.0: rc=${rc} calls: $(tr '\n' ' ' < "${CALL_LOG}")"

# The gate is not debian-specific.
reset
DISTRO_RESULT_VERSION="0.38.0"
run_install rhel "${GOOD_PATH}"; rc=$?
binary_called && [[ "${rc}" -eq 0 ]] \
    && ok "rhel, distro fzf 0.38.0: upstream binary installed (gate is distro-agnostic)" \
    || fail "rhel 0.38.0: rc=${rc} calls: $(tr '\n' ' ' < "${CALL_LOG}")"
reset
DISTRO_RESULT_VERSION="0.54.0"
run_install rhel "${GOOD_PATH}"; rc=$?
! binary_called && [[ "${rc}" -eq 0 && ! -e "${LOCAL_BIN}/fzf" ]] \
    && ok "rhel, distro fzf 0.54.0: no upstream binary (Fedora case)" \
    || fail "rhel 0.54.0: rc=${rc} calls: $(tr '\n' ' ' < "${CALL_LOG}")"

# An unrecognised distro never had a distro installer: still the binary.
reset
run_install none "${GOOD_PATH}"; rc=$?
binary_called && ! distro_called && [[ "${rc}" -eq 0 ]] \
    && ok "unknown distro: upstream binary, no distro installer" \
    || fail "unknown distro: rc=${rc} calls: $(tr '\n' ' ' < "${CALL_LOG}")"

# Distro install fails: the upstream binary, as before.
reset
run_install debian "${GOOD_PATH}"; rc=$?   # DISTRO_RESULT_VERSION unset -> fails
distro_called && binary_called && [[ "${rc}" -eq 0 ]] \
    && ok "debian, distro install fails: upstream binary installed" \
    || fail "debian, distro fails: rc=${rc} calls: $(tr '\n' ' ' < "${CALL_LOG}")"

# Both fail: install-fzf fails.
reset
BINARY_FAILS=1
run_install debian "${GOOD_PATH}"; rc=$?
[[ "${rc}" -ne 0 ]] \
    && ok "debian, distro and upstream both fail: install-fzf fails" \
    || fail "both fail: rc=${rc}"

# The fzf on PATH is the upstream binary: refreshed upstream, the distro
# package is not touched (it could not upgrade the binary anyway).
reset
make_fzf "${LOCAL_BIN}" "0.48.0 (upstream)"
DISTRO_RESULT_VERSION="0.44.1 (debian)"
run_install debian "${GOOD_PATH}"; rc=$?
binary_called && ! distro_called && [[ "${rc}" -eq 0 ]] \
    && ok "active fzf is ~/.local/bin/fzf: no distro installer, upstream binary refreshed" \
    || fail "active ~/.local/bin/fzf: rc=${rc} calls: $(tr '\n' ' ' < "${CALL_LOG}")"
[[ "$("${LOCAL_BIN}/fzf" --version)" == "0.55.0 (upstream)" ]] \
    && ok "active fzf is ~/.local/bin/fzf: the binary was replaced with the new release" \
    || fail "binary not refreshed: $("${LOCAL_BIN}/fzf" --version)"

# A distro fzf ahead of ~/.local/bin on PATH: the new binary is installed
# but loses, so install-fzf must say so and fail rather than report success.
reset
DISTRO_RESULT_VERSION="0.44.1 (debian)"
run_install debian "${DISTRO_BIN}:${LOCAL_BIN}:/usr/bin:/bin"; rc=$?
binary_called && [[ "${rc}" -ne 0 ]] \
    && grep -q "first on PATH but older than 0.48.0" "${WORK}/warnings" \
    && ok "old distro fzf shadows ~/.local/bin on PATH: warns and fails" \
    || fail "shadowed binary: rc=${rc} warnings: $(cat "${WORK}/warnings" 2>/dev/null)"

# ~/.local/bin not on PATH at all: the binary exists but cannot win.
reset
DISTRO_RESULT_VERSION="0.44.1 (debian)"
run_install debian "${DISTRO_BIN}:/usr/bin:/bin"; rc=$?
[[ "${rc}" -ne 0 ]] \
    && ok "upstream binary not on PATH after fallback: install-fzf fails" \
    || fail "binary off PATH: rc=${rc}"

# macOS goes straight to Homebrew and never reaches the gate.
reset
_fzf-install-mac() { echo "mac" >> "${CALL_LOG}"; }
( WORKBENCH_OS="Mac"; PATH="${GOOD_PATH}"; install-fzf >/dev/null 2>&1 )
[[ "$(cat "${CALL_LOG}")" == "mac" ]] \
    && ok "macOS: Homebrew path only, no version gate" \
    || fail "macOS: calls: $(tr '\n' ' ' < "${CALL_LOG}")"

bash -n "${REPO_ROOT}/shell/installers.sh" \
    && ok "bash -n shell/installers.sh" \
    || fail "bash -n shell/installers.sh"

echo
echo "==============================="
echo "Total OK/FAIL checks: ${check_no}, failed: ${FAILED}"
echo "==============================="
[[ "${FAILED}" -eq 0 ]]
