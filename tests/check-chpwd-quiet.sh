#!/usr/bin/env bash
# tests/check-chpwd-quiet.sh — workbench-shell
# shell/zsh.sh lists the directory after a cd through zsh's chpwd_functions
# hook list: never inside $(…) (where the listing became part of captured
# output — workbench-core D96), added once however often the file is
# sourced, and without replacing a chpwd the user already has.
# Plain bash, numbered OK:/FAIL: checks, no framework. Runs the checks in
# a real interactive zsh; SKIP: only when zsh isn't installed.
#
# SC2015: '[[ cond ]] && ok || fail' is this suite's assertion idiom.
# shellcheck disable=SC2015
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

if ! command -v zsh &>/dev/null; then
    echo "SKIP: zsh not installed"
    exit 0
fi

FAILED=0
check_no=0
ok()   { check_no=$((check_no + 1)); echo "OK:   [$check_no] $*"; }
fail() { check_no=$((check_no + 1)); echo "FAIL: [$check_no] $*"; FAILED=$((FAILED + 1)); }

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
mkdir -p "${WORK}/home" "${WORK}/dir"
: > "${WORK}/err"
: > "${WORK}/dir/a-file"

# in_zsh <user-chpwd: yes|no> <commands>: an interactive zsh with no rc
# files, optionally a user chpwd defined, then shell/zsh.sh sourced twice
# (a reload).
in_zsh() {
    local user_chpwd=""
    [[ "$1" == "yes" ]] && user_chpwd='chpwd() { echo MINE; }'
    HOME="${WORK}/home" ZDOTDIR="${WORK}/home" zsh -f -i -c "
        log_debug() { :; }
        ${user_chpwd}
        source '${REPO_ROOT}/shell/zsh.sh'
        source '${REPO_ROOT}/shell/zsh.sh'
        $2" 2>>"${WORK}/err"
}

out="$(in_zsh no "x=\"\$(cd '${WORK}/dir' && pwd)\"; print -r -- \"[\${x}]\"")"
[[ "${out}" == "[${WORK}/dir]" ]] \
    && ok "\$(cd dir && pwd) captures exactly the directory" \
    || fail "captured: ${out}"

# shellcheck disable=SC2016 # expanded by the zsh below, not here
out="$(in_zsh no 'print -r -- ${#${(M)chpwd_functions:#_shell_chpwd_list}}')"
[[ "${out}" == "1" ]] \
    && ok "chpwd_functions holds _shell_chpwd_list once after two sources" \
    || fail "_shell_chpwd_list appears ${out} times"

out="$(in_zsh yes 'whence -w chpwd; chpwd')"
[[ "${out}" == *"chpwd: function"* && "${out}" == *MINE* ]] \
    && ok "a user chpwd defined before sourcing still exists" \
    || fail "user chpwd: ${out}"

out="$(in_zsh yes "cd '${WORK}/dir'")"
[[ "${out}" == *MINE* && "${out}" == *a-file* ]] \
    && ok "a cd at the top level runs both the user's chpwd and the listing" \
    || fail "top-level cd printed: ${out}"

[[ ! -s "${WORK}/err" ]] \
    && ok "nothing on stderr" \
    || fail "stderr: $(cat "${WORK}/err")"

echo
echo "==============================="
echo "Total OK/FAIL checks: ${check_no}, failed: ${FAILED}"
echo "==============================="
[[ "${FAILED}" -eq 0 ]]
