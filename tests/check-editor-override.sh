#!/usr/bin/env bash
# tests/check-editor-override.sh — workbench-shell
# Verifies shell/editors.sh's VISUAL election: with no VISUAL already set,
# the priority (code-insiders > code, GUI sessions only > nvim > vim)
# runs unchanged; with VISUAL already set upstream (this module's own
# overrides.sh, or workbench-core's settings.sh), that value wins outright
# and the election never runs, GUI or not.
#
# D110: an EDITOR that was already set (and a VISUAL that was not) makes
# VISUAL follow EDITOR, so git, crontab and TUIs open the editor the host
# chose. The cases at the end cover that and the plain host without it.
# shellcheck disable=SC2015  # '[[ cond ]] && ok || fail' is this suite's assertion idiom
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

FAILED=0
check_no=0
ok()   { check_no=$((check_no + 1)); echo "OK:   [$check_no] $*"; }
fail() { check_no=$((check_no + 1)); echo "FAIL: [$check_no] $*"; FAILED=$((FAILED + 1)); }

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

mkdir -p "${WORK}/bin-code" "${WORK}/bin-nvim" "${WORK}/bin-code-and-nvim" "${WORK}/bin-empty"
for f in "${WORK}/bin-code/code-insiders" "${WORK}/bin-code-and-nvim/code-insiders"; do
    cat > "${f}" <<'EOF'
#!/usr/bin/env bash
EOF
    chmod +x "${f}"
done
for f in "${WORK}/bin-nvim/nvim" "${WORK}/bin-code-and-nvim/nvim"; do
    cat > "${f}" <<'EOF'
#!/usr/bin/env bash
EOF
    chmod +x "${f}"
done

# run_editors <bindir> [preset_visual] [display]
# Sources editors.sh in a fresh subshell — a controlled PATH decides
# what's "installed"; a non-empty display simulates a GUI session.
# DISPLAY/WAYLAND_DISPLAY are always explicitly set (even if empty) since
# this script runs under set -u and editors.sh references them without a
# ${VAR:-} default. Prints the resulting VISUAL.
run_editors() {
    local bindir="$1" preset="${2:-}" display="${3:-}"
    (
        PATH="${bindir}:/usr/bin:/bin"
        WORKBENCH_OS="Linux"
        DISPLAY=""
        WAYLAND_DISPLAY=""
        # The cases above are about a host with no EDITOR of its own, so a
        # caller's EDITOR must not leak in.
        unset EDITOR VISUAL
        [[ -n "${display}" ]] && DISPLAY=":0"
        [[ -n "${preset}" ]] && VISUAL="${preset}"
        # shellcheck disable=SC1091
        source "${REPO_ROOT}/shell/editors.sh"
        echo "${VISUAL}"
    )
}

# 1. No preset VISUAL, GUI session, code-insiders installed — elects it
#    (unchanged existing behaviour).
result="$(run_editors "${WORK}/bin-code" "" "yes" | tail -1)"
# shellcheck disable=SC2015
[[ "${result}" == "code-insiders --wait" ]] \
    && ok "no preset: elects code-insiders in a GUI session" \
    || fail "no preset: expected 'code-insiders --wait', got '${result}'"

# 2. No preset VISUAL, GUI session, code-insiders AND nvim installed —
#    code-insiders still outranks nvim.
result="$(run_editors "${WORK}/bin-code-and-nvim" "" "yes" | tail -1)"
# shellcheck disable=SC2015
[[ "${result}" == "code-insiders --wait" ]] \
    && ok "no preset: code-insiders outranks nvim when both are present" \
    || fail "no preset, both present: expected 'code-insiders --wait', got '${result}'"

# 3. No preset VISUAL, GUI session, only nvim installed (no code/code-
#    insiders) — nvim wins over the bare vim fallback.
result="$(run_editors "${WORK}/bin-nvim" "" "yes" | tail -1)"
# shellcheck disable=SC2015
[[ "${result}" == "nvim" ]] \
    && ok "no preset, GUI session: nvim wins when no GUI editor is present" \
    || fail "no preset, GUI, nvim only: expected 'nvim', got '${result}'"

# 4. No preset VISUAL, no GUI session, nvim installed — nvim still wins,
#    since it isn't GUI-specific.
result="$(run_editors "${WORK}/bin-nvim" "" "" | tail -1)"
# shellcheck disable=SC2015
[[ "${result}" == "nvim" ]] \
    && ok "no preset, no GUI: nvim still wins over vim when installed" \
    || fail "no preset, no GUI, nvim only: expected 'nvim', got '${result}'"

# 5. No preset VISUAL, no GUI session, nothing installed — falls back to
#    vim (unchanged).
result="$(run_editors "${WORK}/bin-empty" "" "" | tail -1)"
# shellcheck disable=SC2015
[[ "${result}" == "vim" ]] \
    && ok "no preset, no GUI, nothing installed: falls back to vim" \
    || fail "no preset, no GUI, empty: expected 'vim', got '${result}'"

# 6. Preset VISUAL, GUI session, code-insiders installed — preset wins,
#    election never runs.
result="$(run_editors "${WORK}/bin-code" "nvim" "yes" | tail -1)"
# shellcheck disable=SC2015
[[ "${result}" == "nvim" ]] \
    && ok "preset VISUAL=nvim wins over code-insiders despite it being present" \
    || fail "preset VISUAL=nvim: expected 'nvim', got '${result}'"

# 7. Preset VISUAL, no GUI session — preset still wins.
result="$(run_editors "${WORK}/bin-empty" "code --wait" "" | tail -1)"
# shellcheck disable=SC2015
[[ "${result}" == "code --wait" ]] \
    && ok "preset VISUAL wins even outside a GUI session" \
    || fail "preset VISUAL, no GUI: expected 'code --wait', got '${result}'"

# ── D110: VISUAL follows an EDITOR that was set before workbench. ───────────
# run_editors_ex <bindir> <editor> <visual> <display> <passes>
# Sources editors.sh <passes> times in one shell (a second pass is a reload)
# and prints "VISUAL=<..>|EDITOR=<..>" after the last.
run_editors_ex() {
    local bindir="$1" editor="$2" visual="$3" display="$4" passes="$5" n
    (
        PATH="${bindir}:/usr/bin:/bin"
        WORKBENCH_OS="Linux"
        DISPLAY=""
        WAYLAND_DISPLAY=""
        unset EDITOR VISUAL
        [[ -n "${display}" ]] && DISPLAY=":0"
        [[ -n "${editor}" ]] && EDITOR="${editor}"
        [[ -n "${visual}" ]] && VISUAL="${visual}"
        for ((n = 0; n < passes; n++)); do
            # shellcheck disable=SC1091
            source "${REPO_ROOT}/shell/editors.sh"
        done
        echo "VISUAL=${VISUAL}|EDITOR=${EDITOR}"
    )
}

# 8. EDITOR set, VISUAL not: VISUAL follows it, even where the election
#    would have picked code-insiders. A value with arguments stays whole.
result="$(run_editors_ex "${WORK}/bin-code" "fake-editor --inline" "" "yes" 1 | tail -1)"
[[ "${result}" == "VISUAL=fake-editor --inline|EDITOR=fake-editor --inline" ]] \
    && ok "EDITOR set, VISUAL unset: VISUAL follows EDITOR (arguments kept), not the elected editor" \
    || fail "EDITOR set, VISUAL unset: got '${result}'"

# 9. Both set: neither changes.
result="$(run_editors_ex "${WORK}/bin-code" "foo" "bar" "yes" 1 | tail -1)"
[[ "${result}" == "VISUAL=bar|EDITOR=foo" ]] \
    && ok "EDITOR and VISUAL both set: both unchanged" \
    || fail "EDITOR and VISUAL both set: got '${result}'"

# 10. The plain host: neither set. The election result is unchanged and
#     EDITOR gets workbench's default.
result="$(run_editors_ex "${WORK}/bin-code" "" "" "yes" 1 | tail -1)"
[[ "${result}" == "VISUAL=code-insiders --wait|EDITOR=vim" ]] \
    && ok "neither set: existing election runs unchanged (GUI, code-insiders)" \
    || fail "neither set: got '${result}'"
result="$(run_editors_ex "${WORK}/bin-empty" "" "" "" 1 | tail -1)"
[[ "${result}" == "VISUAL=vim|EDITOR=vim" ]] \
    && ok "neither set, nothing installed: vim and vim, as before" \
    || fail "neither set, nothing installed: got '${result}'"

# 11. VISUAL only: EDITOR still gets the default and VISUAL is untouched.
result="$(run_editors_ex "${WORK}/bin-code" "" "bar" "yes" 1 | tail -1)"
[[ "${result}" == "VISUAL=bar|EDITOR=vim" ]] \
    && ok "VISUAL set, EDITOR unset: VISUAL kept, EDITOR defaults to vim" \
    || fail "VISUAL set, EDITOR unset: got '${result}'"

# 12. Reload: a second pass changes nothing, in both starting states.
result="$(run_editors_ex "${WORK}/bin-code" "fake-editor --inline" "" "yes" 2 | tail -1)"
[[ "${result}" == "VISUAL=fake-editor --inline|EDITOR=fake-editor --inline" ]] \
    && ok "reload with a preset EDITOR: no change on the second pass" \
    || fail "reload with a preset EDITOR: got '${result}'"
result="$(run_editors_ex "${WORK}/bin-code" "" "" "yes" 2 | tail -1)"
[[ "${result}" == "VISUAL=code-insiders --wait|EDITOR=vim" ]] \
    && ok "reload on a plain host: no change on the second pass" \
    || fail "reload on a plain host: got '${result}'"

echo
if [[ "${FAILED}" -eq 0 ]]; then
    echo "All ${check_no} checks passed."
    exit 0
else
    echo "${FAILED} of ${check_no} checks failed."
    exit 1
fi
