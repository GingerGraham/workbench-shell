#!/usr/bin/env bash
# tests/check-alias-yield.sh — workbench-shell, workbench-core D110.
#
# shell/aliases.sh defines an alias only when the name is free: not an alias
# or function the host already has. A name this file defined earlier in the
# shell is redefined, so a reload refreshes it. lsa and lsr call `command ls`
# so a host's own `ls` alias cannot change what they mean.
#
# Each case is a small script run by a fresh shell, with the host's
# definitions on lines of their own BEFORE aliases.sh is sourced: an alias is
# expanded when a line is read, so a one-line `bash -c` string would not test
# the right thing. bash and zsh both run every case; SKIP: only when a shell
# is not installed. The Core API pieces aliases.sh calls are no-op stand-ins
# (this suite runs without core). Plain bash, numbered OK:/FAIL: checks.
#
# SC2015: '[[ cond ]] && ok || fail' is this suite's assertion idiom.
# shellcheck disable=SC2015
set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." >/dev/null 2>&1 && pwd)"

FAILED=0
check_no=0
ok()   { check_no=$((check_no + 1)); echo "OK:   [$check_no] $*"; }
fail() { check_no=$((check_no + 1)); echo "FAIL: [$check_no] $*"; FAILED=$((FAILED + 1)); }

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
mkdir -p "${WORK}/home" "${WORK}/bin" "${WORK}/dir"
touch "${WORK}/dir/file_a" "${WORK}/dir/file_b"

# A tmux on PATH so the tmux block of aliases.sh runs.
printf '#!/usr/bin/env bash\nexit 0\n' > "${WORK}/bin/tmux"
chmod +x "${WORK}/bin/tmux"

# run_case <shell> <setup-lines> <after-lines>
# Writes a script: expand aliases, the host's <setup-lines>, the Core API
# stand-ins, aliases.sh, then <after-lines>. Prints the script's output.
run_case() {
    local shell_bin="$1" setup="$2" after="$3" script="${WORK}/case.sh"
    {
        [[ "${shell_bin}" == "bash" ]] && echo 'shopt -s expand_aliases'
        printf '%s\n' "${setup}"
        printf '%s\n' \
            'log_error() { echo "ERROR: $*"; }' \
            '_wb_alias_availability() { :; }' \
            '_wb_declare_availability() { :; }' \
            '_wb_availability_needs() { :; }'
        echo "source '${REPO_ROOT}/shell/aliases.sh' || exit 9"
        printf '%s\n' "${after}"
    } > "${script}"
    HOME="${WORK}/home" PATH="${WORK}/bin:${PATH}" WORKBENCH_OS=Linux "${shell_bin}" "${script}" 2>&1
}

for sh in bash zsh; do
    if ! command -v "${sh}" &>/dev/null; then
        echo "SKIP: ${sh} not installed"
        continue
    fi

    # ── 1. A foreign alias of a name this file defines is left alone. ───────
    out="$(run_case "${sh}" "alias lsa='ls -a'" '
before_text="ls -a"
alias lsa
echo "---"
alias lsr >/dev/null 2>&1 && echo "LSR=defined" || echo "LSR=missing"')"
    [[ "${out}" == *"lsa='ls -a'"* && "${out}" != *"command ls"*"-Alhi"* && "${out}" == *"LSR=defined"* ]] \
        && ok "${sh}: a host's own lsa alias is untouched, and lsr (free) is still defined" \
        || fail "${sh}: foreign alias case: ${out}"

    # ── 2. A foreign function of the same name is left alone. ───────────────
    out="$(run_case "${sh}" 'lsa() { echo "host function"; }' '
lsa
alias lsa >/dev/null 2>&1 && echo "ALIAS=defined-over-function" || echo "ALIAS=none"')"
    [[ "${out}" == *"host function"* && "${out}" == *"ALIAS=none"* ]] \
        && ok "${sh}: a host's own lsa function is untouched; no alias is defined over it" \
        || fail "${sh}: foreign function case: ${out}"

    # ── 3. Nothing pre-existing: defined, and a reload refreshes it. ────────
    out="$(run_case "${sh}" ':' '
alias lsr >/dev/null 2>&1 && echo "FIRST=defined" || echo "FIRST=missing"
alias lsr="stale value"
source "'"${REPO_ROOT}"'/shell/aliases.sh"
alias lsr | grep -q "command ls" && echo "RELOAD=refreshed" || echo "RELOAD=stale"')"
    [[ "${out}" == *"FIRST=defined"* && "${out}" == *"RELOAD=refreshed"* ]] \
        && ok "${sh}: with nothing pre-existing the alias is defined, and a reload refreshes it" \
        || fail "${sh}: plain/reload case: ${out}"

    # ── 4. With an ls alias in place, lsr and lsa still list correctly. ─────
    out="$(run_case "${sh}" "alias ls='printf \"ALIAS-LS-RAN\\n\"; false'" '
cd "'"${WORK}"'/dir"
lsr
lsa')"
    [[ "${out}" == *"file_a"* && "${out}" == *"file_b"* && "${out}" != *"ALIAS-LS-RAN"* ]] \
        && ok "${sh}: lsr and lsa list files with a host ls alias present, and the alias never runs" \
        || fail "${sh}: ls-alias case: ${out}"

    # ── 5. tmux-reload: a host alias or function of the name is kept; 0.7.x's
    #    own alias is still replaced (tests/check-tmux-reload.sh covers the
    #    reload and search-order behaviour). ───────────────────────────────
    out="$(run_case "${sh}" "alias tmux-reload='host-reload-command'" '
alias tmux-reload')"
    [[ "${out}" == *"host-reload-command"* ]] \
        && ok "${sh}: a host's tmux-reload alias is not unaliased" \
        || fail "${sh}: foreign tmux-reload alias: ${out}"
    out="$(run_case "${sh}" 'tmux-reload() { echo "host tmux-reload"; }' '
tmux-reload')"
    [[ "${out}" == *"host tmux-reload"* ]] \
        && ok "${sh}: a host's tmux-reload function is not replaced" \
        || fail "${sh}: foreign tmux-reload function: ${out}"

    # ── 6. The plain host: every alias named in the file is defined, as
    #    before. Names come from the same pattern core's listing uses. ──────
    names="$(grep -Eho '^[[:space:]]*alias [a-zA-Z0-9_-]+=' "${REPO_ROOT}/shell/aliases.sh" \
        | sed -E 's/^[[:space:]]*alias ([a-zA-Z0-9_-]+)=.*/\1/' | sort -u)"
    # A stub for every tool the conditional blocks look for.
    for tool in ip netstat bat batcat btop htop python3 pip3 acpi code-insiders wl-copy nautilus \
                nordvpn cmatrix it2profile get-functions wb dig curl; do
        printf '#!/usr/bin/env bash\nexit 0\n' > "${WORK}/bin/${tool}"
        chmod +x "${WORK}/bin/${tool}"
    done
    missing=""
    for name in ${names}; do
        out="$(run_case "${sh}" ':' "alias ${name} >/dev/null 2>&1 && echo DEFINED || echo MISSING" | tail -1)"
        if [[ "${out}" != "DEFINED" ]]; then
            # Shell-specific names are only defined in their own shell.
            case "${sh}:${name}" in
                bash:zshconfig|bash:zshreload|bash:history|zsh:bashconfig|zsh:bashreload) ;;
                *) missing="${missing} ${name}" ;;
            esac
        fi
    done
    [[ -z "${missing}" ]] \
        && ok "${sh}: plain host: every alias named in aliases.sh is defined" \
        || fail "${sh}: plain host: aliases not defined:${missing}"
    # Clear the stubs again so later shells start from the same PATH.
    for tool in ip netstat bat batcat btop htop python3 pip3 acpi code-insiders wl-copy nautilus \
                nordvpn cmatrix it2profile get-functions wb dig curl; do
        rm -f "${WORK}/bin/${tool}"
    done
done

echo
if [[ "${FAILED}" -eq 0 ]]; then
    echo "All ${check_no} checks passed."
    exit 0
else
    echo "${FAILED} of ${check_no} checks failed."
    exit 1
fi
