#!/usr/bin/env bash
# tests/check-omz-install.sh — workbench-shell
# install-oh-my-zsh (shell/installers.sh) runs oh-my-zsh's installer
# unattended and never touches ~/.zshrc, where workbench's loader stub
# lives; installed-oh-my-zsh checks the install directory, which works in
# the bash process `wb tools` runs it in (the omz command is a zsh function
# and never exists there); and an existing install is updated with
# oh-my-zsh's own tools/upgrade.sh, not reinstalled.
#
# A fake install.sh stands in for upstream's: it records its arguments and
# environment, creates ${ZSH}/oh-my-zsh.sh, and — like the real one without
# KEEP_ZSHRC — replaces ~/.zshrc unless told to keep it. A stub zsh on PATH
# records the upgrade call. No network.
# Plain bash, numbered OK:/FAIL: checks, no framework.
#
# SC2015: '[[ cond ]] && ok || fail' is this suite's assertion idiom.
# SC2088: "~/..." in messages names the path as the user sees it.
# shellcheck disable=SC2015,SC2088
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

FAILED=0
check_no=0
ok()   { check_no=$((check_no + 1)); echo "OK:   [$check_no] $*"; }
fail() { check_no=$((check_no + 1)); echo "FAIL: [$check_no] $*"; FAILED=$((FAILED + 1)); }

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
mkdir -p "${WORK}/home" "${WORK}/bin"
export LOG="${WORK}/calls.log"

cat > "${WORK}/fake-install.sh" <<'FAKE'
#!/bin/sh
printf 'install args: %s\n' "$*" >> "${LOG}"
printf 'install env: ZSH=%s KEEP_ZSHRC=%s RUNZSH=%s CHSH=%s\n' \
    "${ZSH:-}" "${KEEP_ZSHRC:-}" "${RUNZSH:-}" "${CHSH:-}" >> "${LOG}"
mkdir -p "${ZSH}/tools"
echo ':' > "${ZSH}/oh-my-zsh.sh"
[ "${KEEP_ZSHRC:-}" = "yes" ] || echo 'source $ZSH/oh-my-zsh.sh' > "${HOME}/.zshrc"
exit 0
FAKE

# A stub zsh: records how it was called, then runs the script it was given
# with sh so the stubbed upgrade.sh below can record itself too.
cat > "${WORK}/bin/zsh" <<'STUB'
#!/bin/sh
printf 'zsh args: %s (ZSH=%s)\n' "$*" "${ZSH:-}" >> "${LOG}"
[ "$1" = "-f" ] && shift
exec sh "$@"
STUB
chmod +x "${WORK}/bin/zsh"

# in_bash <commands>: shell/installers.sh sourced in a fresh bash, as
# `wb tools` runs it, with the Core API pieces it uses stubbed.
in_bash() {
    HOME="${WORK}/home" PATH="${WORK}/bin:${PATH}" FAKE="${WORK}/fake-install.sh" bash -c "
        log_info()  { :; }
        log_warn()  { :; }
        log_error() { echo \"ERROR: \$*\" >&2; }
        _download_file_robust() { echo \"download \$1\" >> \"\${LOG}\"; cp \"\${FAKE}\" \"\$2\"; }
        source '${REPO_ROOT}/shell/installers.sh' || exit 9
        $1"
}

printf '# my zshrc\nsource ~/.config/workbench/loader.sh # marker\n' > "${WORK}/home/.zshrc"
cp "${WORK}/home/.zshrc" "${WORK}/zshrc.before"

# 1. Not installed yet: the predicate is false in bash.
in_bash 'installed-oh-my-zsh' \
    && fail "installed-oh-my-zsh is true before anything was installed" \
    || ok "installed-oh-my-zsh is false before install (bash)"

# 2–5. Fresh install.
: > "${LOG}"
in_bash 'install-oh-my-zsh'
rc=$?
[[ "${rc}" -eq 0 ]] \
    && ok "install-oh-my-zsh returns 0 (no exec zsh at the end)" \
    || fail "install-oh-my-zsh returned ${rc}"
cmp -s "${WORK}/zshrc.before" "${WORK}/home/.zshrc" \
    && ok "~/.zshrc is byte-identical after install" \
    || fail "~/.zshrc changed: $(cat "${WORK}/home/.zshrc")"
grep -q '^install args: .*--unattended' "${LOG}" && grep -q '^install args: .*--keep-zshrc' "${LOG}" \
    && ok "the installer got --unattended and --keep-zshrc" \
    || fail "installer args: $(grep '^install args' "${LOG}")"
grep -q "^install env: ZSH=${WORK}/home/.oh-my-zsh KEEP_ZSHRC=yes RUNZSH=no CHSH=no$" "${LOG}" \
    && ok "the installer got ZSH=~/.oh-my-zsh KEEP_ZSHRC=yes RUNZSH=no CHSH=no" \
    || fail "installer env: $(grep '^install env' "${LOG}")"

# 6. Installed now: the predicate is true in bash.
in_bash 'installed-oh-my-zsh' \
    && ok "installed-oh-my-zsh is true after install (bash)" \
    || fail "installed-oh-my-zsh is false after install"

# 7–9. Already installed: runs tools/upgrade.sh under zsh -f with ZSH set,
#      and never downloads or runs the installer.
cat > "${WORK}/home/.oh-my-zsh/tools/upgrade.sh" <<'UPGRADE'
printf 'upgrade ran (ZSH=%s)\n' "${ZSH:-}" >> "${LOG}"
UPGRADE
: > "${LOG}"
in_bash 'install-oh-my-zsh'
rc=$?
[[ "${rc}" -eq 0 ]] && grep -q "^upgrade ran (ZSH=${WORK}/home/.oh-my-zsh)$" "${LOG}" \
    && ok "an existing install runs tools/upgrade.sh with ZSH set" \
    || fail "upgrade: rc=${rc}, log: $(cat "${LOG}")"
grep -q "^zsh args: -f ${WORK}/home/.oh-my-zsh/tools/upgrade.sh" "${LOG}" \
    && ok "...under zsh -f" \
    || fail "zsh call: $(grep '^zsh args' "${LOG}")"
! grep -qE '^(download|install args)' "${LOG}" \
    && ok "...and the installer isn't downloaded or run" \
    || fail "installer ran on an existing install: $(cat "${LOG}")"

echo
echo "==============================="
echo "Total OK/FAIL checks: ${check_no}, failed: ${FAILED}"
echo "==============================="
[[ "${FAILED}" -eq 0 ]]
