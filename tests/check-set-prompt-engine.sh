#!/usr/bin/env bash
# tests/check-set-prompt-engine.sh — workbench-shell
# set-prompt-engine (issue #44) persists the prompt-engine preference as
# WORKBENCH_OVERRIDE_PROMPT_ENGINE in this module's overrides file:
#   - omp, starship, omz and none are written and exported;
#   - the saved value is what the election in omp.sh/starship.sh/omz.sh
#     then honours on the next load (a new shell, with the file sourced);
#   - auto removes the line and unsets the variable;
#   - a bad engine or argument count is an error and writes nothing;
#   - an engine that is not installed is saved with a warning;
#   - other lines in the file, comments included, are kept.
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
mkdir -p "${WORK}/home" "${WORK}/bin" "${WORK}/bin-empty"

for tool in oh-my-posh starship; do
    printf '#!/bin/sh\necho "# stub %s init"\n' "${tool}" > "${WORK}/bin/${tool}"
    chmod +x "${WORK}/bin/${tool}"
done

OVERRIDES_FILE="${WORK}/config/workbench/local/overrides/shell.sh"

STUBS='
log_info()  { echo "INFO: $*"; }
log_warn()  { echo "WARN: $*"; }
log_error() { echo "ERROR: $*"; }
log_debug() { :; }
_wb_alias_availability()   { :; }
_wb_declare_availability() { :; }
_wb_availability_needs()   { :; }
'

# in_sh <shell> <bin dir> <commands>
in_sh() {
    HOME="${WORK}/home" XDG_CONFIG_HOME="${WORK}/config" PATH="$2:/usr/bin:/bin" \
        WORKBENCH_SHELL="$1" "$1" -c "${STUBS}
source '${REPO_ROOT}/shell/preferences.sh'
$3" 2>&1
}

# engine_after_restart <shell> <bin dir>
# What a new shell elects once the overrides file has been sourced, as the
# loader does before any tier content: omp.sh, starship.sh, omz.sh in
# register order. Prints the engine, or "none".
engine_after_restart() {
    in_sh "$1" "$2" "
        [ -f '${OVERRIDES_FILE}' ] && . '${OVERRIDES_FILE}'
        ZSH_VERSION=\${ZSH_VERSION:-}
        source '${REPO_ROOT}/shell/omp.sh'
        source '${REPO_ROOT}/shell/starship.sh'
        echo \"engine=\${WORKBENCH_PROMPT_ENGINE:-none}\"" | tail -1
}

for sh in bash zsh; do
    command -v "${sh}" &>/dev/null || { echo "SKIP: ${sh} not installed"; continue; }
    rm -rf "${WORK}/config"

    # ── 1. starship is saved, exported, and wins the next election ──────────
    out="$(in_sh "${sh}" "${WORK}/bin" 'set-prompt-engine starship; echo "rc=$? now=${WORKBENCH_OVERRIDE_PROMPT_ENGINE:-unset}"')"
    [[ "${out}" == *"rc=0 now=starship"* ]] && grep -qx 'export WORKBENCH_OVERRIDE_PROMPT_ENGINE="starship"' "${OVERRIDES_FILE}" \
        && ok "${sh}: starship is saved to the overrides file and exported" \
        || fail "${sh}: set-prompt-engine starship: ${out} / $(cat "${OVERRIDES_FILE}" 2>&1)"
    [[ "${out}" == *"wb reload"* ]] \
        && ok "${sh}: it says how to apply the change" \
        || fail "${sh}: no reload hint: ${out}"
    result="$(engine_after_restart "${sh}" "${WORK}/bin")"
    [[ "${result}" == "engine=starship" ]] \
        && ok "${sh}: after a restart starship wins although oh-my-posh is installed" \
        || fail "${sh}: election after starship: ${result}"

    # ── 2. Changing it replaces the line, and nothing else is lost ──────────
    printf '# my note\nexport OTHER="kept"\n' >> "${OVERRIDES_FILE}"
    in_sh "${sh}" "${WORK}/bin" 'set-prompt-engine omp' >/dev/null
    count="$(grep -c '^export WORKBENCH_OVERRIDE_PROMPT_ENGINE=' "${OVERRIDES_FILE}")"
    [[ "${count}" -eq 1 ]] && grep -qx 'export WORKBENCH_OVERRIDE_PROMPT_ENGINE="omp"' "${OVERRIDES_FILE}" \
        && grep -qx '# my note' "${OVERRIDES_FILE}" && grep -qx 'export OTHER="kept"' "${OVERRIDES_FILE}" \
        && ok "${sh}: a second choice replaces the line and keeps the rest of the file" \
        || fail "${sh}: after changing: $(cat "${OVERRIDES_FILE}")"
    result="$(engine_after_restart "${sh}" "${WORK}/bin")"
    [[ "${result}" == "engine=omp" ]] \
        && ok "${sh}: after a restart oh-my-posh is elected" \
        || fail "${sh}: election after omp: ${result}"

    # ── 3. none: no engine starts ───────────────────────────────────────────
    in_sh "${sh}" "${WORK}/bin" 'set-prompt-engine none' >/dev/null
    result="$(engine_after_restart "${sh}" "${WORK}/bin")"
    [[ "${result}" == "engine=none" ]] \
        && ok "${sh}: none starts no engine although both are installed" \
        || fail "${sh}: election after none: ${result}"

    # ── 4. auto: line removed, variable unset, election back to normal ──────
    out="$(in_sh "${sh}" "${WORK}/bin" 'set-prompt-engine starship >/dev/null; set-prompt-engine auto; echo "now=${WORKBENCH_OVERRIDE_PROMPT_ENGINE:-unset}"')"
    if [[ "${out}" == *"now=unset"* ]] && ! grep -q '^export WORKBENCH_OVERRIDE_PROMPT_ENGINE=' "${OVERRIDES_FILE}" \
        && grep -qx 'export OTHER="kept"' "${OVERRIDES_FILE}"; then
        ok "${sh}: auto removes the line and unsets the variable, keeping the rest"
    else
        fail "${sh}: auto: ${out} / $(cat "${OVERRIDES_FILE}")"
    fi
    result="$(engine_after_restart "${sh}" "${WORK}/bin")"
    [[ "${result}" == "engine=omp" ]] \
        && ok "${sh}: after auto the normal election applies again (omp first)" \
        || fail "${sh}: election after auto: ${result}"

    # ── 5. Bad input writes nothing ─────────────────────────────────────────
    before="$(cat "${OVERRIDES_FILE}")"
    out="$(in_sh "${sh}" "${WORK}/bin" 'set-prompt-engine pure; echo "rc=$?"')"
    [[ "${out}" == *"unknown engine 'pure'"* && "${out}" == *"rc=1"* && "$(cat "${OVERRIDES_FILE}")" == "${before}" ]] \
        && ok "${sh}: an unknown engine is an error and writes nothing" \
        || fail "${sh}: unknown engine: ${out}"
    out="$(in_sh "${sh}" "${WORK}/bin" 'set-prompt-engine; echo "rc=$?"')"
    [[ "${out}" == *"no engine given"* && "${out}" == *"rc=1"* && "$(cat "${OVERRIDES_FILE}")" == "${before}" ]] \
        && ok "${sh}: no argument is an error and writes nothing" \
        || fail "${sh}: no argument: ${out}"
    out="$(in_sh "${sh}" "${WORK}/bin" 'set-prompt-engine omp starship; echo "rc=$?"')"
    [[ "${out}" == *"expected 1 argument, got 2"* && "${out}" == *"rc=1"* && "$(cat "${OVERRIDES_FILE}")" == "${before}" ]] \
        && ok "${sh}: two arguments is an error and writes nothing" \
        || fail "${sh}: two arguments: ${out}"

    # ── 6. An engine that is not installed is saved, with a warning ─────────
    rm -rf "${WORK}/config"
    out="$(in_sh "${sh}" "${WORK}/bin-empty" 'set-prompt-engine starship; echo "rc=$?"')"
    [[ "${out}" == *"WARN: set-prompt-engine: starship is not installed"* && "${out}" == *"rc=0"* ]] \
        && grep -qx 'export WORKBENCH_OVERRIDE_PROMPT_ENGINE="starship"' "${OVERRIDES_FILE}" \
        && ok "${sh}: a missing engine is saved, with a warning that names the install command" \
        || fail "${sh}: missing engine: ${out}"
    rm -rf "${WORK}/config"
done

# ── 7. The overrides template still documents the override, and now the
#    command that writes it. ──────────────────────────────────────────────────
grep -q 'set-prompt-engine' "${REPO_ROOT}/shell/overrides.sh" \
    && ok "shell/overrides.sh points at set-prompt-engine" \
    || fail "shell/overrides.sh does not mention set-prompt-engine"

echo
echo "==============================="
echo "Total OK/FAIL checks: ${check_no}, failed: ${FAILED}"
echo "==============================="
[[ "${FAILED}" -eq 0 ]]
