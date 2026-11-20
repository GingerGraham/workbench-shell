#!/usr/bin/env bash
# tests/check-overrides-persist.sh — workbench-shell
# Persisting a preference into this module's overrides file (issue #45):
#   - the file is named after the name the module is registered under, read
#     from the path workbench-core sources shell/preferences.sh from, with
#     "shell" only as the fallback for any other path;
#   - set-omp-theme-permanent writes there, and no file of this module
#     names overrides/shell.sh any more;
#   - a value is written as typed, an existing line is replaced in place,
#     and everything else in the file is kept.
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

# A registered copy of preferences.sh, laid out as workbench-core registers
# it: <modules dir>/<name>/current/shell/preferences.sh. The name is not
# "shell", so a hard-coded shell.sh cannot pass.
REGISTERED_NAME="my-shell-module"
REGISTERED_DIR="${WORK}/modules/${REGISTERED_NAME}/current/shell"
# omp.sh looks for themes under ~/.cache/oh-my-posh/themes first.
THEMES="${WORK}/home/.cache/oh-my-posh/themes"
mkdir -p "${REGISTERED_DIR}" "${WORK}/home" "${WORK}/bin" "${THEMES}"
cp "${REPO_ROOT}/shell/preferences.sh" "${REGISTERED_DIR}/preferences.sh"
REGISTERED="${REGISTERED_DIR}/preferences.sh"

printf '#!/bin/sh\necho "# stub oh-my-posh init"\n' > "${WORK}/bin/oh-my-posh"
chmod +x "${WORK}/bin/oh-my-posh"
echo '{}' > "${THEMES}/night.omp.json"
echo '{}' > "${THEMES}/day.omp.json"

OVERRIDES="${WORK}/config/workbench/local/overrides"

STUBS='
log_info()  { echo "INFO: $*"; }
log_warn()  { echo "WARN: $*"; }
log_error() { echo "ERROR: $*"; }
log_debug() { :; }
_wb_alias_availability()   { :; }
_wb_declare_availability() { :; }
_wb_availability_needs()   { :; }
'

# in_sh <shell> <commands>
in_sh() {
    HOME="${WORK}/home" XDG_CONFIG_HOME="${WORK}/config" PATH="${WORK}/bin:/usr/bin:/bin" \
        WORKBENCH_SHELL="$1" "$1" -c "${STUBS}
$2" 2>&1
}

for sh in bash zsh; do
    command -v "${sh}" &>/dev/null || { echo "SKIP: ${sh} not installed"; continue; }
    rm -rf "${WORK}/config"

    # ── 1. The file name follows the registration name ──────────────────────
    out="$(in_sh "${sh}" "source '${REGISTERED}'; _shell_overrides_file")"
    [[ "${out}" == "${OVERRIDES}/${REGISTERED_NAME}.sh" ]] \
        && ok "${sh}: overrides file is named after the registration name" \
        || fail "${sh}: registered path: ${out}"

    # ── 2. Any other path falls back to shell ───────────────────────────────
    out="$(in_sh "${sh}" "source '${REPO_ROOT}/shell/preferences.sh'; _shell_overrides_file")"
    [[ "${out}" == "${OVERRIDES}/shell.sh" ]] \
        && ok "${sh}: a path that is not a registered one falls back to shell.sh" \
        || fail "${sh}: fallback: ${out}"

    # ── 3. The loader's own overrides directory is used when it is set ──────
    out="$(in_sh "${sh}" "WORKBENCH_OVERRIDES_DIR='${WORK}/loader-dir'; source '${REGISTERED}'; _shell_overrides_file")"
    [[ "${out}" == "${WORK}/loader-dir/${REGISTERED_NAME}.sh" ]] \
        && ok "${sh}: WORKBENCH_OVERRIDES_DIR is honoured" \
        || fail "${sh}: WORKBENCH_OVERRIDES_DIR: ${out}"

    # ── 4. set-omp-theme-permanent writes to the registered name's file ─────
    out="$(in_sh "${sh}" "
        source '${REGISTERED}'
        source '${REPO_ROOT}/shell/omp.sh'
        set-omp-theme-permanent night")"
    if [[ -f "${OVERRIDES}/${REGISTERED_NAME}.sh" && ! -e "${OVERRIDES}/shell.sh" ]] \
        && grep -qx 'export OMP_THEME="night"' "${OVERRIDES}/${REGISTERED_NAME}.sh"; then
        ok "${sh}: set-omp-theme-permanent writes ${REGISTERED_NAME}.sh, not shell.sh"
    else
        fail "${sh}: set-omp-theme-permanent: ${out} / files: $(ls "${OVERRIDES}" 2>&1)"
    fi
    [[ "${out}" == *"${OVERRIDES}/${REGISTERED_NAME}.sh"* ]] \
        && ok "${sh}: the confirmation names the file it wrote" \
        || fail "${sh}: confirmation: ${out}"

    # ── 5. A second call replaces the line; the rest of the file is kept ────
    file="${OVERRIDES}/${REGISTERED_NAME}.sh"
    printf '# my note\n# export OMP_THEME="commented-example"\nexport OTHER="kept"\n' | cat - "${file}" > "${file}.new"
    mv "${file}.new" "${file}"
    in_sh "${sh}" "
        source '${REGISTERED}'
        source '${REPO_ROOT}/shell/omp.sh'
        set-omp-theme-permanent day" >/dev/null
    count="$(grep -c '^export OMP_THEME=' "${file}")"
    [[ "${count}" -eq 1 ]] && grep -qx 'export OMP_THEME="day"' "${file}" \
        && ok "${sh}: a second call replaces the OMP_THEME line instead of adding one" \
        || fail "${sh}: OMP_THEME lines: $(cat "${file}")"
    grep -qx '# my note' "${file}" && grep -qx 'export OTHER="kept"' "${file}" \
        && grep -qx '# export OMP_THEME="commented-example"' "${file}" \
        && ok "${sh}: other lines and commented examples are kept" \
        || fail "${sh}: file after replace: $(cat "${file}")"

    # ── 6. A value is written as typed ──────────────────────────────────────
    out="$(in_sh "${sh}" "
        source '${REGISTERED}'
        _shell_override_set WB_TEST_VALUE 'a&b\\c/d'
        _shell_override_set WB_TEST_VALUE 'x&y\\z/w'
        . \"\$(_shell_overrides_file)\"
        echo \"\${WB_TEST_VALUE}\"")"
    [[ "${out}" == 'x&y\z/w' ]] \
        && ok "${sh}: '&', backslash and '/' in a value are written as typed" \
        || fail "${sh}: special characters: ${out}"
done

# ── 7. Nothing in the module names the overrides file by hand ───────────────
if grep -rn 'overrides/shell\.sh' "${REPO_ROOT}/shell" | grep -vE '^[^:]+:[0-9]+:[[:space:]]*#' | grep -q .; then
    fail "shell/ still builds the path overrides/shell.sh in code"
else
    ok "no code in shell/ hard-codes overrides/shell.sh"
fi

echo
echo "==============================="
echo "Total OK/FAIL checks: ${check_no}, failed: ${FAILED}"
echo "==============================="
[[ "${FAILED}" -eq 0 ]]
