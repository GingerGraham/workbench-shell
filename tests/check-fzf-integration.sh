#!/usr/bin/env bash
# tests/check-fzf-integration.sh — workbench-shell
# shell/fzf.sh evaluates `fzf --bash` / `fzf --zsh` only when it printed
# something, and says so — once, in interactive shells only — when it did
# not. fzf older than 0.48.0 has neither flag: it prints an error on stderr
# and nothing on stdout, which used to look exactly like success, so
# Ctrl-R silently stayed on the shell's own history search.
#
# Stub fzf executables in a temp PATH directory stand in for the real
# tool, in a temp HOME. No network.
# Plain bash, numbered OK:/FAIL: checks, no framework. zsh checks SKIP:
# only when zsh isn't installed.
#
# SC2015: '[[ cond ]] && ok || fail' is this suite's assertion idiom.
# SC2016: the single-quoted snippets are expanded by the shell they run in.
# shellcheck disable=SC2015,SC2016
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

FAILED=0
check_no=0
ok()   { check_no=$((check_no + 1)); echo "OK:   [$check_no] $*"; }
fail() { check_no=$((check_no + 1)); echo "FAIL: [$check_no] $*"; FAILED=$((FAILED + 1)); }

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
mkdir -p "${WORK}/home" "${WORK}/bin-new" "${WORK}/bin-old" "${WORK}/bin-none"

# A current fzf: both integration flags print a script that sets a marker.
cat > "${WORK}/bin-new/fzf" <<'EOF'
#!/bin/sh
case "$1" in
    --bash|--zsh) echo "_WB_FZF_TEST_INIT=1" ;;
    --version)    echo "0.50.0 (stub)" ;;
esac
EOF

# fzf 0.44.1 as Pop!_OS ships it: no --bash/--zsh, error on stderr only.
cat > "${WORK}/bin-old/fzf" <<'EOF'
#!/bin/sh
case "$1" in
    --bash|--zsh) echo "unknown option: $1" >&2; exit 2 ;;
    --version)    echo "0.44.1 (debian)" ;;
esac
EOF
chmod +x "${WORK}/bin-new/fzf" "${WORK}/bin-old/fzf"

STUBS='
log_info()  { :; }
log_warn()  { echo "WARN: $*" >&2; }
log_error() { echo "ERROR: $*" >&2; }
log_debug() { echo "DEBUG: $*"; }
'

# run_fzf_sh <shell> <interactive: yes|no> <PATH prefix>
# Sources fzf.sh under WORKBENCH_SHELL=<shell>. stdout (including the
# marker) goes to ${WORK}/out, stderr to ${WORK}/err.
run_fzf_sh() {
    local sh="$1" interactive="$2" path_prefix="$3" flags="-c"
    [[ "${interactive}" == "yes" ]] && flags="-ic"
    HOME="${WORK}/home" PATH="${path_prefix}:/usr/bin:/bin" "${sh}" ${flags} "${STUBS}
        WORKBENCH_SHELL=${sh}
        source '${REPO_ROOT}/shell/fzf.sh'
        echo \"marker=\${_WB_FZF_TEST_INIT:-unset}\"
        echo \"leftover=\${_wb_fzf_init-unset}\"" >"${WORK}/out" 2>"${WORK}/err"
}

# Only WARN lines count: an interactive shell with no terminal adds its own
# job-control noise to stderr.
warnings() { grep '^WARN:' "${WORK}/err" || true; }

for sh in bash zsh; do
    if ! command -v "${sh}" &>/dev/null; then
        echo "SKIP: ${sh} not installed"
        continue
    fi

    # 1. fzf with working integration: evaluated, no warning.
    run_fzf_sh "${sh}" yes "${WORK}/bin-new"
    [[ "$(grep -c '^marker=1$' "${WORK}/out")" -eq 1 && -z "$(warnings)" ]] \
        && ok "${sh}: current fzf — integration evaluated, no warning" \
        || fail "${sh}: current fzf: out=$(cat "${WORK}/out") warnings=$(warnings)"
    grep -q '^leftover=unset$' "${WORK}/out" \
        && ok "${sh}: the capture variable is not left behind" \
        || fail "${sh}: _wb_fzf_init leaked: $(cat "${WORK}/out")"

    # 2. Old fzf, interactive: not evaluated, one warning with version and fix.
    run_fzf_sh "${sh}" yes "${WORK}/bin-old"
    warn="$(warnings)"
    [[ "$(grep -c '^marker=unset$' "${WORK}/out")" -eq 1 ]] \
        && ok "${sh}: old fzf, interactive — nothing evaluated" \
        || fail "${sh}: old fzf marker: $(cat "${WORK}/out")"
    [[ "$(printf '%s\n' "${warn}" | grep -c .)" -eq 1 \
        && "${warn}" == *"0.44.1"* && "${warn}" == *"0.48.0"* \
        && "${warn}" == *"wb tools upgrade fzf"* ]] \
        && ok "${sh}: old fzf, interactive — one warning naming the version and the fix" \
        || fail "${sh}: old fzf warning: ${warn}"
    [[ "${warn}" != *"(debian)"* ]] \
        && ok "${sh}: the warning quotes the version number only" \
        || fail "${sh}: warning carries the distro suffix: ${warn}"

    # 3. Old fzf, non-interactive: silent.
    run_fzf_sh "${sh}" no "${WORK}/bin-old"
    [[ -z "$(warnings)" && "$(grep -c '^marker=unset$' "${WORK}/out")" -eq 1 ]] \
        && ok "${sh}: old fzf, non-interactive — no warning" \
        || fail "${sh}: non-interactive: out=$(cat "${WORK}/out") warnings=$(warnings)"

    # 4. No fzf: only the debug line, no warning. Skipped when the host has
    # a real fzf in /usr/bin or /bin that the stub-free PATH would find.
    if [[ -x /usr/bin/fzf || -x /bin/fzf ]]; then
        ok "(${sh}: fzf is installed in /usr/bin or /bin — not-installed case skipped)"
    else
        run_fzf_sh "${sh}" yes "${WORK}/bin-none"
        [[ -z "$(warnings)" ]] \
            && grep -q '^DEBUG: fzf: not installed' "${WORK}/out" \
            && ok "${sh}: no fzf — debug line only, no warning" \
            || fail "${sh}: no fzf: out=$(cat "${WORK}/out") warnings=$(warnings)"
    fi
done

# The old `source <(…)` form must not come back.
grep -qE '^[^#]*source <\(' "${REPO_ROOT}/shell/fzf.sh" \
    && fail "fzf.sh uses source <(…) (a no-op on bash 3.2)" \
    || ok "fzf.sh has no source <(…)"
# Neither may the swallow-everything form that hid the original failure.
grep -E '^[^#]*fzf --(bash|zsh)' "${REPO_ROOT}/shell/fzf.sh" | grep -q '|| true' \
    && fail "fzf.sh ignores the exit status of fzf --bash/--zsh again" \
    || ok "fzf.sh does not '|| true' the integration call"

bash -n "${REPO_ROOT}/shell/fzf.sh" \
    && ok "bash -n shell/fzf.sh" \
    || fail "bash -n shell/fzf.sh"

echo
if [[ "${FAILED}" -eq 0 ]]; then
    echo "All ${check_no} checks passed."
else
    echo "${FAILED} of ${check_no} checks failed."
    exit 1
fi
