#!/usr/bin/env bash
# tests/check-source-aliases.sh — workbench-shell
# zshsource and bashsource (issue #46): each re-reads its shell's rc file in
# the current shell, and each exists only in its own shell. An alias or
# function of the same name that was there first is left alone
# (workbench-core D110).
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
mkdir -p "${WORK}/home"

# Each rc file sets a marker, so a run shows which file was sourced.
echo 'RC_SOURCED=bashrc' > "${WORK}/home/.bashrc"
echo 'RC_SOURCED=zshrc'  > "${WORK}/home/.zshrc"

STUBS='
log_info()  { :; }
log_warn()  { :; }
log_error() { :; }
log_debug() { :; }
_wb_alias_availability()   { :; }
_wb_declare_availability() { :; }
_wb_availability_needs()   { :; }
'

# in_sh <shell> <commands>
# Aliases are not expanded in a non-interactive bash unless asked for, and
# zsh parses a whole -c string before running any of it, so the commands run
# through eval: they are parsed after aliases.sh has defined its aliases.
in_sh() {
    local sh="$1" expand=""
    [[ "${sh}" == "bash" ]] && expand="shopt -s expand_aliases"
    HOME="${WORK}/home" PATH="/usr/bin:/bin" "${sh}" -c "${STUBS}
${expand}
source '${REPO_ROOT}/shell/aliases.sh'
eval \"\$1\"" _ "$2" 2>&1
}

# ── bash ────────────────────────────────────────────────────────────────────
out="$(in_sh bash 'bashsource; echo "marker=${RC_SOURCED:-unset}"')"
[[ "${out}" == "marker=bashrc" ]] \
    && ok "bash: bashsource sources ~/.bashrc in the current shell" \
    || fail "bash: bashsource: ${out}"

out="$(in_sh bash 'alias zshsource >/dev/null 2>&1 && echo defined || echo missing')"
[[ "${out}" == "missing" ]] \
    && ok "bash: zshsource is not defined" \
    || fail "bash: zshsource: ${out}"

# bashsource runs in the current shell: a variable the rc file sets is still
# there afterwards, which a new shell (bashreload) would not give you.
out="$(in_sh bash 'RC_SOURCED=before; bashsource; echo "${RC_SOURCED}"')"
[[ "${out}" == "bashrc" ]] \
    && ok "bash: bashsource changes the current shell, not a child" \
    || fail "bash: bashsource scope: ${out}"

out="$(in_sh bash 'alias bashsource >/dev/null 2>&1 && echo defined || echo missing' )"
[[ "${out}" == "defined" ]] \
    && ok "bash: bashsource is defined" \
    || fail "bash: bashsource defined: ${out}"

# A host's own bashsource wins (D110).
out="$(HOME="${WORK}/home" PATH="/usr/bin:/bin" bash -c "${STUBS}
shopt -s expand_aliases
alias bashsource='echo host-bashsource'
source '${REPO_ROOT}/shell/aliases.sh'
bashsource" 2>&1)"
[[ "${out}" == "host-bashsource" ]] \
    && ok "bash: a host's bashsource alias is left alone" \
    || fail "bash: host bashsource: ${out}"

# ── zsh ─────────────────────────────────────────────────────────────────────
if command -v zsh &>/dev/null; then
    out="$(in_sh zsh 'zshsource; echo "marker=${RC_SOURCED:-unset}"')"
    [[ "${out}" == "marker=zshrc" ]] \
        && ok "zsh: zshsource sources ~/.zshrc in the current shell" \
        || fail "zsh: zshsource: ${out}"

    out="$(in_sh zsh 'alias bashsource >/dev/null 2>&1 && echo defined || echo missing')"
    [[ "${out}" == "missing" ]] \
        && ok "zsh: bashsource is not defined" \
        || fail "zsh: bashsource: ${out}"

    out="$(in_sh zsh 'RC_SOURCED=before; zshsource; echo "${RC_SOURCED}"')"
    [[ "${out}" == "zshrc" ]] \
        && ok "zsh: zshsource changes the current shell, not a child" \
        || fail "zsh: zshsource scope: ${out}"
else
    echo "SKIP: zsh not installed"
fi

echo
echo "==============================="
echo "Total OK/FAIL checks: ${check_no}, failed: ${FAILED}"
echo "==============================="
[[ "${FAILED}" -eq 0 ]]
