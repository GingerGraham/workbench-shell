#!/usr/bin/env bash
# tests/check-add-to-core.sh — workbench-shell
# Run by workbench-core's module CI ("add to core", step 8) with WB,
# MODULE_NAME, MODULE_URL, MODULE_BRANCH and MODULE_ROOT set. Builds its own
# scratch HOME seeded with a user's ~/.tmux.conf and ~/.vimrc, adds this
# branch of the module the way the shared check does, and proves the
# tmux.conf and vimrc layers (workbench-core docs/decisions-log.md D82):
# each file starts with a workbench block, the user's lines follow
# unchanged, no second tmux config is created, and — where tmux and vim
# are installed — the user's settings win while the module's apply
# underneath.
#
# SC2015: '[[ cond ]] && ok || fail' is this suite's assertion idiom.
# SC2088: "~/..." in messages names the path as the user sees it.
# shellcheck disable=SC2015,SC2088
set -uo pipefail

# Module CI's structural-tests job also runs every tests/check-*.sh on its
# own, without a core checkout: nothing to add the module to there.
if [[ -z "${WB:-}" || -z "${MODULE_NAME:-}" || -z "${MODULE_URL:-}" || -z "${MODULE_BRANCH:-}" ]]; then
    echo "SKIP: needs WB, MODULE_NAME, MODULE_URL and MODULE_BRANCH — run by workbench-core's module CI ('add to core', step 8)"
    exit 0
fi

FAILED=0
check_no=0
ok()   { check_no=$((check_no + 1)); echo "OK:   [$check_no] $*"; }
fail() { check_no=$((check_no + 1)); echo "FAIL: [$check_no] $*"; FAILED=$((FAILED + 1)); }

WORK="$(mktemp -d)"
trap 'tmux -L wb-add-to-core kill-server 2>/dev/null; rm -rf "${WORK}"' EXIT
export HOME="${WORK}/home"
export XDG_CONFIG_HOME="${HOME}/.config"
export XDG_DATA_HOME="${HOME}/.local/share"
mkdir -p "${HOME}"
unset TMUX

printf 'set -g mouse off\n' > "${HOME}/.tmux.conf"
printf 'set nonumber\n' > "${HOME}/.vimrc"

run() { "$@" >"${WORK}/out.log" 2>&1 || { echo "--- $* failed:"; cat "${WORK}/out.log"; return 1; }; }
run "${WB}" add "${MODULE_NAME}" "${MODULE_URL}" --keep-files </dev/null || fail "wb add"
run "${WB}" track "${MODULE_NAME}" --branch "${MODULE_BRANCH}" </dev/null || fail "wb track"
run "${WB}" update "${MODULE_NAME}" </dev/null || fail "wb update"

[[ "$(head -n 1 "${HOME}/.tmux.conf")" == "# >>> workbench ${MODULE_NAME}/tmux.conf under >>>" ]] \
    && ok "~/.tmux.conf starts with the workbench block" \
    || { fail "~/.tmux.conf block"; cat "${HOME}/.tmux.conf"; }
[[ "$(tail -n 1 "${HOME}/.tmux.conf")" == "set -g mouse off" \
    && "$(grep -c 'mouse' "${HOME}/.tmux.conf")" -eq 1 ]] \
    && ok "your tmux line follows the block, unchanged" \
    || { fail "~/.tmux.conf user line"; cat "${HOME}/.tmux.conf"; }
[[ "$(head -n 1 "${HOME}/.vimrc")" == "\" >>> workbench ${MODULE_NAME}/vimrc under >>>" ]] \
    && ok "~/.vimrc starts with the workbench block" \
    || { fail "~/.vimrc block"; cat "${HOME}/.vimrc"; }
[[ "$(tail -n 1 "${HOME}/.vimrc")" == "set nonumber" ]] \
    && ok "your vim line follows the block, unchanged" \
    || { fail "~/.vimrc user line"; cat "${HOME}/.vimrc"; }
[[ ! -e "${XDG_CONFIG_HOME}/tmux/tmux.conf" ]] \
    && ok "no ~/.config/tmux/tmux.conf created (tmux would read only one of the two)" \
    || fail "~/.config/tmux/tmux.conf was created"
[[ -f "${XDG_CONFIG_HOME}/starship.toml" && -f "${XDG_CONFIG_HOME}/direnv/direnv.toml" ]] \
    && ok "starship.toml and direnv.toml are still deployed" \
    || fail "starship.toml or direnv.toml missing"

if command -v tmux &>/dev/null; then
    # A stub TPM: the module's config clones TPM and installs plugins when
    # ~/.tmux/plugins/tpm is missing — no network from a test.
    mkdir -p "${HOME}/.tmux/plugins/tpm"
    printf '#!/bin/sh\nexit 0\n' > "${HOME}/.tmux/plugins/tpm/tpm"
    chmod +x "${HOME}/.tmux/plugins/tpm/tpm"
    if tmux -L wb-add-to-core -f "${HOME}/.tmux.conf" new-session -d -s t 2>"${WORK}/tmux.err"; then
        [[ "$(tmux -L wb-add-to-core show -gv mouse)" == "off" ]] \
            && ok "tmux: your 'mouse off' wins" \
            || fail "tmux mouse is '$(tmux -L wb-add-to-core show -gv mouse)'"
        [[ "$(tmux -L wb-add-to-core show -gv history-limit)" == "10000" ]] \
            && ok "tmux: the module's history-limit applies" \
            || fail "tmux history-limit is '$(tmux -L wb-add-to-core show -gv history-limit)'"
        tmux -L wb-add-to-core kill-server 2>/dev/null
    else
        fail "tmux won't start with the layered config: $(cat "${WORK}/tmux.err")"
    fi
else
    echo "SKIP: tmux not installed — tmux behaviour checks skipped"
fi

if command -v vim &>/dev/null; then
    vim -N -u "${HOME}/.vimrc" -es \
        -c "redir! > ${WORK}/vim.out | set number? | set encoding? | redir END" -c 'qa!' </dev/null >/dev/null 2>&1
    grep -q '^nonumber$' "${WORK}/vim.out" \
        && ok "vim: your 'set nonumber' wins" \
        || fail "vim number: $(tr '\n' ' ' < "${WORK}/vim.out")"
    grep -q 'encoding=utf-8' "${WORK}/vim.out" \
        && ok "vim: the module's encoding applies" \
        || fail "vim encoding: $(tr '\n' ' ' < "${WORK}/vim.out")"
else
    echo "SKIP: vim not installed — vim behaviour checks skipped"
fi

echo
echo "==============================="
echo "Total OK/FAIL checks: ${check_no}, failed: ${FAILED}"
echo "==============================="
[[ "${FAILED}" -eq 0 ]]
