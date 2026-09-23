#!/usr/bin/env bash
# tests/check-reset-shell-no-pager.sh — workbench-shell
# workbench-core docs/decisions-log.md D73: reset-shell/rs are meant to
# redisplay the same quick summary a fresh shell's WORKBENCH_SHOW_FUNCTIONS
# startup banner already shows you, not inherit wb functions' interactive
# pager and full aliases listing once workbench-core's `wb functions`
# gained a pager. Verifies the alias definitions themselves carry
# --no-pager --no-aliases, and that aliases (whose whole purpose is the
# full listing) is deliberately left unchanged.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

FAILED=0
check_no=0
ok()   { check_no=$((check_no + 1)); echo "OK:   [$check_no] $*"; }
fail() { check_no=$((check_no + 1)); echo "FAIL: [$check_no] $*"; FAILED=$((FAILED + 1)); }

# get-functions is workbench-core's, not this module's — stub it so
# shell/aliases.sh's `command -v get-functions` gate is satisfied and the
# three aliases actually get defined. ZSH_VERSION is explicitly set (even
# though empty) since this script runs under set -u and aliases.sh
# references it without a ${VAR:-} default — same convention
# tests/check-editor-override.sh already uses for editors.sh's DISPLAY/
# WAYLAND_DISPLAY references.
get-functions() { :; }
ZSH_VERSION=""
# shellcheck disable=SC1091
source "${REPO_ROOT}/shell/aliases.sh"

reset_shell_def="$(alias reset-shell 2>/dev/null)"
rs_def="$(alias rs 2>/dev/null)"
aliases_def="$(alias aliases 2>/dev/null)"

# shellcheck disable=SC2015
[[ "${reset_shell_def}" == *"get-functions --no-pager --no-aliases"* ]] \
    && ok "reset-shell calls get-functions --no-pager --no-aliases" \
    || fail "reset-shell does not call get-functions with --no-pager --no-aliases: ${reset_shell_def}"

# shellcheck disable=SC2015
[[ "${rs_def}" == *"get-functions --no-pager --no-aliases"* ]] \
    && ok "rs calls get-functions --no-pager --no-aliases" \
    || fail "rs does not call get-functions with --no-pager --no-aliases: ${rs_def}"

# shellcheck disable=SC2015
[[ "${aliases_def}" == *"='get-functions'" ]] \
    && ok "aliases is left as a bare get-functions call — the full listing is its whole purpose" \
    || fail "aliases unexpectedly changed: ${aliases_def}"

echo
if [[ "${FAILED}" -eq 0 ]]; then
    echo "All ${check_no} checks passed."
    exit 0
else
    echo "${FAILED} of ${check_no} checks failed."
    exit 1
fi
