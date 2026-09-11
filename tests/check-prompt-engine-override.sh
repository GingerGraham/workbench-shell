#!/usr/bin/env bash
# tests/check-prompt-engine-override.sh — workbench-shell
# Verifies WORKBENCH_OVERRIDE_PROMPT_ENGINE (workbench-core ARCHITECTURE.md
# §12 D48): with no override, the existing install-presence/load-order
# election is unchanged; with an override set, it wins regardless of
# install presence or load order, and falls through cleanly (never to the
# unoverridden election) when the named engine isn't actually installed.
#
# Mocks oh-my-posh/starship as tiny stub scripts on a controlled PATH and
# oh-my-zsh as a one-line oh-my-zsh.sh, rather than requiring any of the
# three actually installed — this runs on a bare CI runner unchanged.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

FAILED=0
check_no=0
ok()   { check_no=$((check_no + 1)); echo "OK:   [$check_no] $*"; }
fail() { check_no=$((check_no + 1)); echo "FAIL: [$check_no] $*"; FAILED=$((FAILED + 1)); }

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

mkdir -p "${WORK}/bin"
cat > "${WORK}/bin/oh-my-posh" <<'EOF'
#!/usr/bin/env bash
echo '# stub oh-my-posh init'
EOF
cat > "${WORK}/bin/starship" <<'EOF'
#!/usr/bin/env bash
echo '# stub starship init'
EOF
chmod +x "${WORK}/bin/oh-my-posh" "${WORK}/bin/starship"

# shellcheck disable=SC2317 # called indirectly by the sourced election guards
log_info()  { :; }
log_warn()  { echo "WARN: $*"; }
log_debug() { :; }
# shellcheck disable=SC2317 # called indirectly by the sourced election guards
log_error() { echo "ERROR: $*"; }

# run_election <bindir> [override] [omz-present]
# Sources all three election guard files, in register order, in a fresh
# subshell — a controlled PATH decides which of oh-my-posh/starship are
# "installed", omz-present (any non-empty value) creates a working
# ~/.oh-my-zsh/oh-my-zsh.sh stub. Prints the resulting WORKBENCH_PROMPT_ENGINE,
# or "none" if nothing elected.
run_election() {
    local bindir="$1" override="${2:-}" omz_present="${3:-}"
    (
        PATH="${bindir}:/usr/bin:/bin"
        WORKBENCH_SHELL=bash
        ZSH_VERSION="5.9"   # simulates zsh for omz.sh's guard, harmlessly noisy under real bash (zstyle: command not found on stderr, stdout unaffected)
        HOME="${WORK}/home-$$-${RANDOM}"
        mkdir -p "${HOME}"
        if [[ -n "${omz_present}" ]]; then
            mkdir -p "${HOME}/.oh-my-zsh"
            echo ':' > "${HOME}/.oh-my-zsh/oh-my-zsh.sh"
        fi
        [[ -n "${override}" ]] && WORKBENCH_OVERRIDE_PROMPT_ENGINE="${override}"
        # shellcheck disable=SC1091
        source "${REPO_ROOT}/shell/omp.sh"
        # shellcheck disable=SC1091
        source "${REPO_ROOT}/shell/starship.sh"
        # shellcheck disable=SC1091
        source "${REPO_ROOT}/shell/omz.sh"
        echo "${WORKBENCH_PROMPT_ENGINE:-none}"
    )
}

# 1. No override, both omp and starship "installed" — omp wins (unchanged
#    register-order election).
result="$(run_election "${WORK}/bin" "" "true" | tail -1)"
# shellcheck disable=SC2015 # ok()/fail() never fail; not an if/then/else
[[ "${result}" == "omp" ]] \
    && ok "no override: omp wins when both omp and starship are present" \
    || fail "no override: expected omp, got '${result}'"

# 2. Override to starship, even though omp is also "installed".
result="$(run_election "${WORK}/bin" "starship" "true" | tail -1)"
# shellcheck disable=SC2015 # ok()/fail() never fail; not an if/then/else
[[ "${result}" == "starship" ]] \
    && ok "override=starship wins over omp despite omp being present" \
    || fail "override=starship: expected starship, got '${result}'"

# 3. Override to omp, but oh-my-posh is NOT on PATH — falls through to no
#    engine, never back to the unoverridden election.
no_omp_bin="${WORK}/bin-no-omp"
mkdir -p "${no_omp_bin}"
cp "${WORK}/bin/starship" "${no_omp_bin}/"
result="$(run_election "${no_omp_bin}" "omp" "true" | tail -1)"
# shellcheck disable=SC2015 # ok()/fail() never fail; not an if/then/else
[[ "${result}" == "none" ]] \
    && ok "override=omp but not installed falls through to no engine" \
    || fail "override=omp missing: expected none, got '${result}'"

# 4. Override to omz, with omp/starship both "installed" — omz wins
#    despite both higher-priority engines being present.
result="$(run_election "${WORK}/bin" "omz" "true" | tail -1)"
# shellcheck disable=SC2015 # ok()/fail() never fail; not an if/then/else
[[ "${result}" == "omz" ]] \
    && ok "override=omz wins over both omp and starship" \
    || fail "override=omz: expected omz, got '${result}'"

echo
if [[ "${FAILED}" -eq 0 ]]; then
    echo "All ${check_no} checks passed."
    exit 0
else
    echo "${FAILED} of ${check_no} checks failed."
    exit 1
fi
