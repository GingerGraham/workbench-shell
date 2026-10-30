#!/usr/bin/env bash
# tests/check-zsh-default-shell.sh — workbench-shell
# install-zsh-default-shell and installed-zsh-default-shell
# (shell/installers.sh) go by the account's login shell as the system
# records it, not ${SHELL}, which keeps its old value until the next desktop
# login (workbench-core D107). So straight after chsh the tool reads as
# installed and isn't re-run; /bin/zsh and /usr/bin/zsh both count; and a
# failed chsh is reported as a failure.
#
# The login shell is faked: stub getent and dscl on PATH read it from a
# file, and a stub chsh records its arguments and writes that file. A stub
# zsh on PATH stands in for the real one, and elevation is a shell function
# that records the call instead of running it. Nothing touches a real
# account or /etc/shells.
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
mkdir -p "${WORK}/home" "${WORK}/bin"
export LOG="${WORK}/calls.log"
export FAKE_LOGIN_SHELL_FILE="${WORK}/login-shell"

cat > "${WORK}/bin/getent" <<'STUB'
#!/bin/sh
[ "$1" = "passwd" ] || exit 2
printf '%s:x:1000:1000::/home/%s:%s\n' "$2" "$2" "$(cat "${FAKE_LOGIN_SHELL_FILE}")"
STUB
cat > "${WORK}/bin/dscl" <<'STUB'
#!/bin/sh
printf 'UserShell: %s\n' "$(cat "${FAKE_LOGIN_SHELL_FILE}")"
STUB
# chsh -s <path>: records the call; exits ${FAKE_CHSH_RC:-0}, and only on
# success records <path> as the login shell.
cat > "${WORK}/bin/chsh" <<'STUB'
#!/bin/sh
printf 'chsh %s\n' "$*" >> "${LOG}"
rc="${FAKE_CHSH_RC:-0}"
[ "${rc}" = "0" ] && [ "$1" = "-s" ] && printf '%s\n' "$2" > "${FAKE_LOGIN_SHELL_FILE}"
exit "${rc}"
STUB
printf '#!/bin/sh\nexit 0\n' > "${WORK}/bin/zsh"
chmod +x "${WORK}/bin/getent" "${WORK}/bin/dscl" "${WORK}/bin/chsh" "${WORK}/bin/zsh"
STUB_ZSH="${WORK}/bin/zsh"

set_login_shell() { printf '%s\n' "$1" > "${FAKE_LOGIN_SHELL_FILE}"; }
chsh_calls() { grep -c '^chsh ' "${LOG}" 2>/dev/null || true; }

# in_bash <commands>: shell/installers.sh sourced in a fresh bash, as
# `wb tools` runs it, with the Core API pieces it uses stubbed. ${SHELL} is
# bash throughout: the desktop session started before any chsh.
in_bash() {
    HOME="${WORK}/home" PATH="${WORK}/bin:${PATH}" SHELL=/bin/bash bash -c "
        log_info()  { echo \"INFO: \$*\"; }
        log_warn()  { echo \"WARN: \$*\"; }
        log_error() { echo \"ERROR: \$*\" >&2; }
        get-elevation-command() { echo _test_elevate; }
        _test_elevate() { printf 'elevate %s\n' \"\$*\" >> \"\${LOG}\"; cat >/dev/null; }
        source '${REPO_ROOT}/shell/installers.sh' || exit 9
        $1"
}

# ── 1. Login shell bash: not installed. ────────────────────────────────────
set_login_shell /bin/bash
in_bash 'installed-zsh-default-shell' >/dev/null 2>&1 \
    && fail "login shell bash: installed-zsh-default-shell reported installed" \
    || ok "login shell bash: installed-zsh-default-shell is false"

# ── 2-4. Install runs chsh with the zsh on PATH, and says to log out. ──────
: > "${LOG}"
out="$(in_bash 'install-zsh-default-shell' 2>&1)"
rc=$?
[[ "${rc}" -eq 0 ]] && grep -qxF "chsh -s ${STUB_ZSH}" "${LOG}" \
    && ok "install-zsh-default-shell ran 'chsh -s ${STUB_ZSH}' and returned 0" \
    || { fail "install-zsh-default-shell (rc ${rc}): expected one 'chsh -s ${STUB_ZSH}'"; cat "${LOG}"; echo "${out}"; }
printf '%s\n' "${out}" | grep -q "Log out of your desktop session" \
    && ok "the success message says to log out of the desktop session" \
    || { fail "success message doesn't mention logging out"; echo "${out}"; }
grep -q "^elevate tee -a /etc/shells" "${LOG}" \
    && ok "a zsh path missing from /etc/shells is added through elevation first" \
    || { fail "no elevated /etc/shells append recorded"; cat "${LOG}"; }

# ── 5-6. The bug: straight after chsh, ${SHELL} is still bash. ─────────────
in_bash 'installed-zsh-default-shell' >/dev/null 2>&1 \
    && ok "after chsh, with \${SHELL} still bash: installed-zsh-default-shell is true" \
    || fail "after chsh: installed-zsh-default-shell still false (reading \${SHELL}?)"
: > "${LOG}"
out="$(in_bash 'install-zsh-default-shell' 2>&1)"
rc=$?
[[ "${rc}" -eq 0 && "$(chsh_calls)" -eq 0 ]] \
    && printf '%s\n' "${out}" | grep -q "log out of your desktop session" \
    && ok "re-running it doesn't call chsh again, and says this session predates the change" \
    || { fail "re-run (rc ${rc}) called chsh $(chsh_calls) time(s), or no relogin hint"; echo "${out}"; }

# ── 7. /bin/zsh counts, though PATH's zsh is elsewhere. ────────────────────
set_login_shell /bin/zsh
in_bash 'installed-zsh-default-shell' >/dev/null 2>&1 \
    && ok "login shell /bin/zsh with a different zsh on PATH: installed" \
    || fail "login shell /bin/zsh not recognised (compared full paths?)"

# ── 8. A failed chsh is a failure, not a success message. ──────────────────
set_login_shell /bin/bash
: > "${LOG}"
out="$(FAKE_CHSH_RC=1 in_bash 'install-zsh-default-shell' 2>&1)"
rc=$?
[[ "${rc}" -ne 0 ]] && [[ "$(cat "${FAKE_LOGIN_SHELL_FILE}")" == "/bin/bash" ]] \
    && printf '%s\n' "${out}" | grep -q "chsh failed" \
    && ! printf '%s\n' "${out}" | grep -q "Login shell changed" \
    && ok "chsh failing: non-zero exit, error reported, no 'changed' message" \
    || { fail "chsh failing (rc ${rc}) was not reported as a failure"; echo "${out}"; }

# ── 9. No zsh at all: refuses, never calls chsh. ───────────────────────────
rm -f "${STUB_ZSH}"
: > "${LOG}"
HOME="${WORK}/home" PATH="${WORK}/bin:/usr/bin:/bin" SHELL=/bin/bash bash -c "
    log_info() { :; }; log_error() { echo \"ERROR: \$*\" >&2; }
    command -v zsh >/dev/null && exit 3
    source '${REPO_ROOT}/shell/installers.sh' || exit 9
    install-zsh-default-shell" >/dev/null 2>&1
rc=$?
if [[ "${rc}" -eq 3 ]]; then
    echo "SKIP: [9] a real zsh is installed in /usr/bin or /bin — can't test the no-zsh path here."
else
    [[ "${rc}" -ne 0 && "$(chsh_calls)" -eq 0 ]] \
        && ok "no zsh installed: refuses without calling chsh" \
        || fail "no zsh installed (rc ${rc}): chsh called $(chsh_calls) time(s)"
fi

echo
echo "==============================="
echo "Total OK/FAIL checks: ${check_no}, failed: ${FAILED}"
echo "==============================="
[[ "${FAILED}" -eq 0 ]]
