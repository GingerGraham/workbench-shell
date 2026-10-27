#!/usr/bin/env bash
# tests/check-tmux-reload.sh — workbench-shell
# shell/aliases.sh's tmux-reload: re-sourcing the file in a shell that
# still has 0.7.x's tmux-reload alias (what 'wb update' does when it
# reloads the shell) parses and leaves a function, not the old alias; and
# the function reloads the first config in tmux's own search order.
# A stub tmux on PATH records what it was asked to source.
# Plain bash, numbered OK:/FAIL: checks, no framework.
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
mkdir -p "${WORK}/bin" "${WORK}/home"
cat > "${WORK}/bin/tmux" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" > "${HOME}/tmux-called"
STUB
chmod +x "${WORK}/bin/tmux"

# 0.7.x's alias, verbatim.
OLD_ALIAS="alias tmux-reload='tmux source-file \"\${HOME}/.config/tmux/tmux.conf\"'"

# in_shell <shell> <commands>: aliases.sh sourced after the old alias.
in_shell() {
    HOME="${WORK}/home" PATH="${WORK}/bin:${PATH}" "$1" -c "
        $([[ "$1" == "bash" ]] && echo 'shopt -s expand_aliases')
        ${OLD_ALIAS}
        log_error() { echo \"ERROR: \$*\"; }
        _wb_alias_availability() { :; }
        _wb_declare_availability() { :; }
        _wb_availability_needs() { :; }
        source '${REPO_ROOT}/shell/aliases.sh' || exit 9
        $2" 2>&1
}

for sh in bash zsh; do
    if ! command -v "${sh}" &>/dev/null; then
        echo "SKIP: ${sh} not installed"
        continue
    fi
    out="$(in_shell "${sh}" 'echo "rc=$?"')"
    [[ "${out}" == *"rc=0"* && "${out}" != *"error"* ]] \
        && ok "${sh}: re-sourcing over the 0.7.x alias parses" \
        || fail "${sh}: ${out}"
    out="$(in_shell "${sh}" 'whence -w tmux-reload 2>/dev/null || type -t tmux-reload')"
    [[ "${out}" == *"function"* ]] \
        && ok "${sh}: tmux-reload is the function, not the old alias" \
        || fail "${sh}: tmux-reload is: ${out}"
done

# The function reloads the first config in tmux's search order.
rm -f "${WORK}/home/tmux-called"
mkdir -p "${WORK}/home/.config/tmux"
: > "${WORK}/home/.config/tmux/tmux.conf"
: > "${WORK}/home/.tmux.conf"
in_shell bash 'unset XDG_CONFIG_HOME; tmux-reload' >/dev/null
[[ "$(cat "${WORK}/home/tmux-called" 2>/dev/null)" == "source-file ${WORK}/home/.tmux.conf" ]] \
    && ok "with both present, reloads ~/.tmux.conf (what tmux reads)" \
    || fail "reloaded: $(cat "${WORK}/home/tmux-called" 2>/dev/null)"
rm -f "${WORK}/home/.tmux.conf" "${WORK}/home/tmux-called"
in_shell bash 'unset XDG_CONFIG_HOME; tmux-reload' >/dev/null
[[ "$(cat "${WORK}/home/tmux-called" 2>/dev/null)" == "source-file ${WORK}/home/.config/tmux/tmux.conf" ]] \
    && ok "with only ~/.config/tmux/tmux.conf, reloads that" \
    || fail "reloaded: $(cat "${WORK}/home/tmux-called" 2>/dev/null)"

echo
echo "==============================="
echo "Total OK/FAIL checks: ${check_no}, failed: ${FAILED}"
echo "==============================="
[[ "${FAILED}" -eq 0 ]]
