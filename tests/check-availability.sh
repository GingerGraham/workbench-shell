#!/usr/bin/env bash
# tests/check-availability.sh — workbench-shell
# Every public name in this module's registered shell files either always
# exists, or declares what it needs (workbench-core docs/module-authoring.md,
# "Declaring function availability"): listings read the files statically,
# so a name defined only when its tool exists must say so, or `wb
# functions` shows it as available when it isn't — or under "module gave no
# reason".
#
# Sources every register.shell file, in manifest order, in bash and in zsh,
# twice: with none of the tools on PATH, and with a stub for every one.
#   - nothing installed: each name that isn't defined has a predicate that
#     says unavailable, and a needs text;
#   - everything installed: each name whose predicate says available is
#     defined;
#   - every declaration names a real name and carries a needs text.
# Names are found with the same patterns core's listing uses
# (_extract_function_names / _extract_alias_names, lib/core/functions.sh).
# The declaration helpers are stand-ins with core's contract (they define
# _<name>-available and record the needs text); this suite runs without core.
# Plain bash, numbered OK:/FAIL: checks, no framework. SKIP: for zsh only
# when zsh isn't installed.
#
# SC2015: '[[ cond ]] && ok || fail' is this suite's assertion idiom.
# shellcheck disable=SC2015
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

FAILED=0
check_no=0
ok()   { check_no=$((check_no + 1)); echo "OK:   [$check_no] $*"; }
fail() { check_no=$((check_no + 1)); echo "FAIL: [$check_no] $*"; FAILED=$((FAILED + 1)); }

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

# Registered shell files, in manifest order.
FILES=""
while IFS= read -r src; do
    FILES="${FILES} ${REPO_ROOT}/${src}"
done < <(awk '/^  shell:/{f=1; next} f && /^  [a-z]/{f=0} f && /src:/{print $NF}' "${REPO_ROOT}/workbench.yml")
# shellcheck disable=SC2086 # FILES is a space-separated list of repo paths
set -- ${FILES}
[[ $# -ge 10 ]] && ok "found $# register.shell files in workbench.yml" || fail "found only $# register.shell files"

# Public names, as core's listing extracts them.
grep -Eho \
    -e '^[[:space:]]*[a-zA-Z_-][a-zA-Z0-9_-]*[[:space:]]*\(\)' \
    -e '^[[:space:]]*function[[:space:]]+[a-zA-Z_-][a-zA-Z0-9_-]*' "$@" \
    | sed -E 's/^[[:space:]]*//; s/^function[[:space:]]+//; s/[[:space:]]*\(\)$//' \
    | grep -v '^_' > "${WORK}/names"
grep -Eho '^[[:space:]]*alias [a-zA-Z0-9_-]+=' "$@" \
    | sed -E 's/^[[:space:]]*alias ([a-zA-Z0-9_-]+)=.*/\1/' >> "${WORK}/names"
sort -u -o "${WORK}/names" "${WORK}/names"

# A PATH with only basic utilities, and one that adds a stub for every tool
# the files check for.
mkdir -p "${WORK}/base" "${WORK}/tools" "${WORK}/home"
for t in ls cat grep sed awk head tail tr sort uniq dirname basename uname \
         mkdir rm mv cp find mktemp env sh bash zsh readlink wc cut id tput; do
    p="$(command -v "${t}" 2>/dev/null)" && [[ "${p}" == /* ]] && ln -sf "${p}" "${WORK}/base/${t}"
done
for t in ip netstat bat batcat btop htop dig curl ssh-add python3 pip3 acpi \
         tmux code code-insiders wl-copy nautilus nordvpn cmatrix it2profile \
         wb oh-my-posh starship direnv fzf fd; do
    printf '#!/bin/sh\nexit 0\n' > "${WORK}/tools/${t}"
    chmod +x "${WORK}/tools/${t}"
done

# The script each shell runs: stubs, every file sourced, then one line per
# name — "<name> <defined 0|1> <predicate none|0|1>" — on fd 3.
cat > "${WORK}/probe.sh" <<'PROBE'
log_info()  { :; }
log_warn()  { :; }
log_error() { :; }
log_debug() { :; }
_wb_prompt_hook_registered() { return 1; }
_wb_availability_needs() {
    local _i=""
    if [ "$1" = "--install" ]; then _i="$2"; shift 2; fi
    local _needs="$1" _n; shift
    for _n in "$@"; do printf '%s\t%s\n' "${_n}" "${_needs}" >> "${DECL}"; done
}
_wb_declare_availability() {
    local _c="$1" _n; shift
    for _n in "$@"; do eval "_${_n}-available() { command -v \"${_c}\" >/dev/null 2>&1; }"; done
    _wb_availability_needs --install "${_c}" "${_c}" "$@"
}
_wb_alias_availability() {
    local _needs="" _have="" _i=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --needs)   _needs="$2"; _have=1; shift 2 ;;
            --install) _i="$2"; shift 2 ;;
            *) break ;;
        esac
    done
    local _c="$1" _n; shift
    for _n in "$@"; do eval "_${_n}-available() { ${_c}; }"; done
    if [ -n "${_have}" ]; then _wb_availability_needs "${_needs}" "$@"; fi
    return 0
}
[ "${WITH_TOOLS}" = "yes" ] && get-functions() { :; }
# eval: FILES is space-separated, and zsh doesn't word-split ${FILES}.
eval "for _f in ${FILES}; do . \"\${_f}\"; done"
while IFS= read -r _n; do
    _def=0
    { alias "${_n}" || typeset -f "${_n}"; } >/dev/null 2>&1 && _def=1
    _pred=none
    if typeset -f "_${_n}-available" >/dev/null 2>&1; then
        if "_${_n}-available"; then _pred=1; else _pred=0; fi
    fi
    printf '%s %s %s\n' "${_n}" "${_def}" "${_pred}" >&3
done < "${NAMES}"
PROBE

# probe <shell> <with-tools: yes|no>: runs probe.sh, writes
# ${WORK}/<shell>-<mode>.out and .decl.
probe() {
    local sh="$1" mode="$2" path="${WORK}/base"
    [[ "${mode}" == "yes" ]] && path="${WORK}/tools:${WORK}/base"
    : > "${WORK}/${sh}-${mode}.decl"
    env -i HOME="${WORK}/home" PATH="${path}" TERM=dumb \
        WORKBENCH_SHELL="${sh}" WORKBENCH_OS="Linux" WITH_TOOLS="${mode}" \
        NAMES="${WORK}/names" DECL="${WORK}/${sh}-${mode}.decl" \
        FILES="${FILES}" \
        "$(command -v "${sh}")" -c ". '${WORK}/probe.sh'" \
        3>"${WORK}/${sh}-${mode}.out" >/dev/null 2>"${WORK}/${sh}-${mode}.err"
}

for sh in bash zsh; do
    if ! command -v "${sh}" &>/dev/null; then
        echo "SKIP: ${sh} not installed"
        continue
    fi
    probe "${sh}" no
    probe "${sh}" yes

    [[ "$(wc -l < "${WORK}/${sh}-no.out")" -eq "$(wc -l < "${WORK}/names")" ]] \
        && ok "${sh}: probed all $(wc -l < "${WORK}/names" | tr -d ' ') names" \
        || fail "${sh}: probe incomplete: $(cat "${WORK}/${sh}-no.err")"

    # Nothing installed: undefined ⇒ a predicate that says no, with a reason.
    bad=""
    while read -r n def pred; do
        [[ "${def}" == "1" ]] && continue
        if [[ "${pred}" != "0" ]]; then
            bad="${bad} ${n}(predicate:${pred})"
        elif ! cut -f1 "${WORK}/${sh}-no.decl" | grep -qxF "${n}"; then
            bad="${bad} ${n}(no needs text)"
        fi
    done < "${WORK}/${sh}-no.out"
    [[ -z "${bad}" ]] \
        && ok "${sh}, nothing installed: every name that isn't defined declares what it needs" \
        || fail "${sh}, nothing installed: undeclared or wrongly declared:${bad}"

    # Everything installed: predicate says yes ⇒ defined.
    bad=""
    while read -r n def pred; do
        [[ "${pred}" == "1" && "${def}" != "1" ]] && bad="${bad} ${n}"
    done < "${WORK}/${sh}-yes.out"
    [[ -z "${bad}" ]] \
        && ok "${sh}, everything installed: every name declared available is defined" \
        || fail "${sh}, everything installed: declared available but not defined:${bad}"

    # Every declaration is for a real name, with a needs text.
    bad=""
    while IFS="$(printf '\t')" read -r n needs; do
        grep -qxF "${n}" "${WORK}/names" || bad="${bad} ${n}(not a name in shell/)"
        [[ -n "${needs}" ]] || bad="${bad} ${n}(empty needs text)"
    done < "${WORK}/${sh}-no.decl"
    [[ -z "${bad}" ]] \
        && ok "${sh}: every declaration names a real name and says what it needs" \
        || fail "${sh}: bad declarations:${bad}"
done

echo
echo "==============================="
echo "Total OK/FAIL checks: ${check_no}, failed: ${FAILED}"
echo "==============================="
[[ "${FAILED}" -eq 0 ]]
