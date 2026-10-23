#!/usr/bin/env bash
# tests/check-direnv-hook-guard.sh — workbench-shell
# shell/direnv.sh hooks direnv into bash only when nothing has already —
# your own rc file, another setup, or workbench-git (workbench-core
# docs/decisions-log.md D83) — so the hook never runs twice per prompt.
# A fake direnv on PATH records each 'direnv hook' evaluation.
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
mkdir -p "${WORK}/bin"
EVALS="${WORK}/evals"
export EVALS

# 'direnv hook bash' prints what the real one does in outline: define
# _direnv_hook and add it to PROMPT_COMMAND. Evaluating it is recorded.
cat > "${WORK}/bin/direnv" <<'FAKE'
#!/usr/bin/env bash
if [[ "${1:-}" == "hook" ]]; then
    cat <<HOOK
echo evaluated >> "${EVALS}"
_direnv_hook() { :; }
PROMPT_COMMAND="_direnv_hook\${PROMPT_COMMAND:+;\${PROMPT_COMMAND}}"
HOOK
fi
FAKE
chmod +x "${WORK}/bin/direnv"

# run_direnv_sh <preset PROMPT_COMMAND>
# Sources shell/direnv.sh in a fresh subshell, with workbench-core's log
# functions and its Core API 1.6 _wb_prompt_hook_registered (copied from
# lib/core/functions.sh — this suite runs without core). Prints the
# resulting PROMPT_COMMAND.
run_direnv_sh() {
    (
        PATH="${WORK}/bin:${PATH}"
        WORKBENCH_SHELL="bash"
        PROMPT_COMMAND="$1"
        log_warn()  { :; }
        log_debug() { :; }
        _wb_prompt_hook_registered() {
            [[ "${PROMPT_COMMAND[*]:-}" == *"$1"* ]]
        }
        # shellcheck source=shell/direnv.sh
        source "${REPO_ROOT}/shell/direnv.sh"
        printf '%s\n' "${PROMPT_COMMAND}"
    )
}

# 1–2. Nothing hooked yet: the hook is evaluated once.
: > "${EVALS}"
result="$(run_direnv_sh "")"
[[ "$(wc -l < "${EVALS}" | tr -d ' ')" -eq 1 ]] \
    && ok "not hooked yet: 'direnv hook bash' is evaluated" \
    || fail "not hooked yet: evaluated $(wc -l < "${EVALS}") times"
[[ "${result}" == "_direnv_hook" ]] \
    && ok "...and _direnv_hook is in PROMPT_COMMAND" \
    || fail "PROMPT_COMMAND is '${result}'"

# 3–4. Already hooked by something else: left alone.
: > "${EVALS}"
result="$(run_direnv_sh "_direnv_hook;my_prompt")"
[[ ! -s "${EVALS}" ]] \
    && ok "already hooked: 'direnv hook' isn't evaluated again" \
    || fail "already hooked: evaluated $(wc -l < "${EVALS}") times"
[[ "${result}" == "_direnv_hook;my_prompt" ]] \
    && ok "...and PROMPT_COMMAND is unchanged" \
    || fail "PROMPT_COMMAND is '${result}'"

echo
echo "==============================="
echo "Total OK/FAIL checks: ${check_no}, failed: ${FAILED}"
echo "==============================="
[[ "${FAILED}" -eq 0 ]]
