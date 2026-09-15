#!/usr/bin/env bash
# tests/check-editor-override.sh — workbench-shell
# Verifies shell/editors.sh's VISUAL election: with no VISUAL already set,
# the priority (code-insiders > code, GUI sessions only > nvim > vim)
# runs unchanged; with VISUAL already set upstream (this module's own
# overrides.sh, or workbench-core's settings.sh), that value wins outright
# and the election never runs, GUI or not.
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

echo
if [[ "${FAILED}" -eq 0 ]]; then
    echo "All ${check_no} checks passed."
    exit 0
else
    echo "${FAILED} of ${check_no} checks failed."
    exit 1
fi
