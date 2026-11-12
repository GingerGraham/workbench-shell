#!/usr/bin/env bash
# tests/check-starship-guard.sh — workbench-shell, workbench-core D110.
#
# shell/starship.sh runs `starship init` only when starship_precmd is not
# already hooked in. A host whose profile ran it first keeps its single hook
# and its STARSHIP_SESSION_KEY; the prompt is still marked as claimed so the
# fallback prompt does not override the host's. A fake starship on PATH
# records every `init` it is asked for and, like the real one, gives each run
# a new random session key.
# Plain bash, numbered OK:/FAIL: checks, no framework.
#
# SC2015: '[[ cond ]] && ok || fail' is this suite's assertion idiom.
# SC2016: the single-quoted bodies are expanded by the shell they run in.
# shellcheck disable=SC2015,SC2016
set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." >/dev/null 2>&1 && pwd)"

FAILED=0
check_no=0
ok()   { check_no=$((check_no + 1)); echo "OK:   [$check_no] $*"; }
fail() { check_no=$((check_no + 1)); echo "FAIL: [$check_no] $*"; FAILED=$((FAILED + 1)); }

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
mkdir -p "${WORK}/bin"
INITS="${WORK}/inits"
export INITS

cat > "${WORK}/bin/starship" <<'FAKE'
#!/usr/bin/env bash
if [[ "${1:-}" == "init" ]]; then
    echo init >> "${INITS}"
    cat <<'INIT'
starship_precmd() { :; }
PROMPT_COMMAND="starship_precmd${PROMPT_COMMAND:+;${PROMPT_COMMAND}}"
export STARSHIP_SESSION_KEY="key-$RANDOM$RANDOM"
INIT
fi
FAKE
chmod +x "${WORK}/bin/starship"

# run_starship <body> — starship.sh sourced in a clean bash with core's log
# functions and Core API 1.6's _wb_prompt_hook_registered (copied from
# lib/core/functions.sh; this suite runs without core). <body> runs after
# a first source and may source it again with `pass`.
run_starship() {
    : > "${INITS}"
    env -i HOME="${WORK}" PATH="${WORK}/bin:/usr/bin:/bin" INITS="${INITS}" \
        WORKBENCH_SHELL=bash bash -c '
        log_warn() { :; }; log_debug() { :; }
        _wb_declare_availability() { :; }
        _wb_prompt_hook_registered() { [[ "${PROMPT_COMMAND[*]:-}" == *"$1"* ]]; }
        pass() { source "'"${REPO_ROOT}"'/shell/starship.sh"; }
        '"$1" 2>&1
}

count_inits() { wc -l < "${INITS}" | tr -d ' '; }
value_of() { printf '%s\n' "$1" | grep "^$2=" | sed "s/^$2=//"; }

# 1. starship_precmd already registered by the host: no init, one hook, the
#    host's key kept, and the prompt is still claimed.
out="$(run_starship '
PROMPT_COMMAND="starship_precmd;host_other"
STARSHIP_SESSION_KEY=host-key
pass
echo "PC=${PROMPT_COMMAND}"; echo "KEY=${STARSHIP_SESSION_KEY}"
echo "SET=${WORKBENCH_PROMPT_SET:-unset}"; echo "ENGINE=${WORKBENCH_PROMPT_ENGINE:-unset}"')"
[[ "$(count_inits)" -eq 0 ]] \
    && ok "starship_precmd already registered: starship init is not run" \
    || fail "starship init ran $(count_inits) time(s) with starship_precmd already registered"
[[ "$(value_of "${out}" PC)" == "starship_precmd;host_other" && "$(value_of "${out}" KEY)" == "host-key" ]] \
    && ok "...the host's PROMPT_COMMAND and STARSHIP_SESSION_KEY are untouched" \
    || fail "host state changed: ${out}"
[[ "$(value_of "${out}" SET)" == "true" && "$(value_of "${out}" ENGINE)" == "starship" ]] \
    && ok "...and the prompt is still marked as claimed" \
    || fail "prompt not claimed: ${out}"

# 2. Not registered: init runs once, as before.
out="$(run_starship '
pass
echo "PC=${PROMPT_COMMAND}"; echo "SET=${WORKBENCH_PROMPT_SET:-unset}"')"
[[ "$(count_inits)" -eq 1 && "$(value_of "${out}" PC)" == "starship_precmd" && "$(value_of "${out}" SET)" == "true" ]] \
    && ok "not registered: starship init runs once, hooks in once and claims the prompt" \
    || fail "not registered: inits=$(count_inits) ${out}"

# 3a. Two passes, hook still registered between them (nothing removed it):
#     one init, one hook, same key.
out="$(run_starship '
pass; first="${STARSHIP_SESSION_KEY}"
pass
echo "PC=${PROMPT_COMMAND}"; echo "SAME=$([[ "${STARSHIP_SESSION_KEY}" == "${first}" ]] && echo yes || echo no)"')"
[[ "$(count_inits)" -eq 1 && "$(value_of "${out}" PC)" == "starship_precmd" && "$(value_of "${out}" SAME)" == "yes" ]] \
    && ok "two passes: one init, one starship_precmd, STARSHIP_SESSION_KEY unchanged" \
    || fail "two passes: inits=$(count_inits) ${out}"

# 3b. Two passes with the hook removed between them (what the loader's
#     reload does to an entry workbench added): init runs again, still one
#     hook, and the session key is the one the shell already had.
out="$(run_starship '
pass; first="${STARSHIP_SESSION_KEY}"
unset PROMPT_COMMAND
pass
echo "PC=${PROMPT_COMMAND}"; echo "SAME=$([[ "${STARSHIP_SESSION_KEY}" == "${first}" ]] && echo yes || echo no)"')"
[[ "$(count_inits)" -eq 2 && "$(value_of "${out}" PC)" == "starship_precmd" && "$(value_of "${out}" SAME)" == "yes" ]] \
    && ok "reload after the loader removed the hook: one hook again, STARSHIP_SESSION_KEY unchanged" \
    || fail "reload: inits=$(count_inits) ${out}"

echo
if [[ "${FAILED}" -eq 0 ]]; then
    echo "All ${check_no} checks passed."
    exit 0
else
    echo "${FAILED} of ${check_no} checks failed."
    exit 1
fi
