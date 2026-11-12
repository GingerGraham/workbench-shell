#!/usr/bin/env bash
# tests/check-existing-setup-coexistence.sh — workbench-shell, workbench-core
# D110 acceptance check.
#
# The module's pieces together, on a host that already has a shell profile:
# editors.sh, aliases.sh, fzf.sh and starship.sh are sourced in manifest
# order after a hand-built distro-style profile has set EDITOR and friends,
# an `ls` alias and `lsa`, FZF_DEFAULT_OPTS, and a prompt with starship
# already hooked in. Nothing the host set may change; what is free gets
# workbench's defaults. The same files on a host with nothing set (the
# plain-host twin) give today's results. Each piece has its own suite; this
# checks they do not undo each other.
#
# Core API pieces the files call are stand-ins (this suite runs without
# core). Plain bash, numbered OK:/FAIL: checks, no framework.
#
# SC2015: '[[ cond ]] && ok || fail' is this suite's assertion idiom.
# SC2016: the single-quoted fixtures are expanded by the shell they run in.
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
mkdir -p "${WORK}/bin" "${WORK}/home" "${WORK}/dir"
touch "${WORK}/dir/file_a"
INITS="${WORK}/inits"
export INITS

# Stand-ins for the tools the files look for.
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
for tool in fd bat tmux; do printf '#!/usr/bin/env bash\nexit 0\n' > "${WORK}/bin/${tool}"; done
chmod +x "${WORK}/bin/"*

# run_profile <host-profile-lines> <after-lines> — one clean bash: the host
# profile first, then the module's files in manifest order, then <after>.
run_profile() {
    : > "${INITS}"
    {
        echo 'shopt -s expand_aliases'
        printf '%s\n' "$1"
        printf '%s\n' \
            'log_warn() { :; }; log_debug() { :; }; log_info() { :; }; log_error() { :; }' \
            '_wb_declare_availability() { :; }; _wb_alias_availability() { :; }; _wb_availability_needs() { :; }' \
            '_wb_prompt_hook_registered() { [[ "${PROMPT_COMMAND[*]:-}" == *"$1"* ]]; }' \
            'WORKBENCH_SHELL=bash; WORKBENCH_OS=Linux; DISPLAY=""; WAYLAND_DISPLAY=""'
        for f in editors aliases fzf starship; do
            echo ". '${REPO_ROOT}/shell/${f}.sh'"
        done
        printf '%s\n' "$2"
    } > "${WORK}/profile.sh"
    env -i HOME="${WORK}/home" PATH="${WORK}/bin:/usr/bin:/bin" INITS="${INITS}" bash "${WORK}/profile.sh" 2>&1
}

value_of() { printf '%s\n' "$1" | grep "^$2=" | sed "s/^$2=//"; }

REPORT='
echo "EDITOR=${EDITOR-<unset>}"; echo "SUDO_EDITOR=${SUDO_EDITOR-<unset>}"; echo "VISUAL=${VISUAL-<unset>}"
echo "BAT_THEME=${BAT_THEME-<unset>}"; echo "FZF_DEFAULT_OPTS=${FZF_DEFAULT_OPTS-<unset>}"
echo "FZF_DEFAULT_COMMAND=${FZF_DEFAULT_COMMAND-<unset>}"
echo "PC=${PROMPT_COMMAND[*]}"; echo "SET=${WORKBENCH_PROMPT_SET-<unset>}"
echo "LSA=$(alias lsa 2>/dev/null || echo none)"; echo "LS=$(alias ls 2>/dev/null || echo none)"
echo "LSR=$(alias lsr 2>/dev/null || echo none)"'

# ── The host with its own profile. ─────────────────────────────────────────
out="$(run_profile '
export EDITOR="fake-editor --inline"
export SUDO_EDITOR="fake-editor --inline"
export BAT_THEME=ansi
export FZF_DEFAULT_OPTS="--host-options"
alias lsa="ls -a"
alias ls="printf \"ALIAS-LS-RAN\\n\"; false"
PROMPT_COMMAND=(starship_precmd "title" __zoxide_hook __zoxide_hook)' "${REPORT}
cd '${WORK}/dir'
echo LSR-OUTPUT-START
lsr
echo LSR-OUTPUT-END")"
lsr_block="$(printf '%s\n' "${out}" | sed -n '/^LSR-OUTPUT-START$/,/^LSR-OUTPUT-END$/p')"

[[ "$(value_of "${out}" EDITOR)" == "fake-editor --inline" \
    && "$(value_of "${out}" SUDO_EDITOR)" == "fake-editor --inline" \
    && "$(value_of "${out}" BAT_THEME)" == "ansi" ]] \
    && ok "host profile: EDITOR, SUDO_EDITOR and BAT_THEME are unchanged" \
    || fail "host profile: ${out}"
[[ "$(value_of "${out}" VISUAL)" == "fake-editor --inline" ]] \
    && ok "host profile: VISUAL follows the host's EDITOR" \
    || fail "host profile: VISUAL is '$(value_of "${out}" VISUAL)'"
[[ "$(value_of "${out}" LSA)" == *"ls -a"* && "$(value_of "${out}" LSA)" != *"command ls"* \
    && "$(value_of "${out}" LS)" == *"ALIAS-LS-RAN"* ]] \
    && ok "host profile: the host's lsa and ls aliases are intact" \
    || fail "host profile: aliases changed: LSA=$(value_of "${out}" LSA) LS=$(value_of "${out}" LS)"
[[ "${lsr_block}" == *"file_a"* && "${lsr_block}" != *"ALIAS-LS-RAN"* ]] \
    && ok "host profile: lsr (workbench's, free) lists files and the host's ls alias never runs" \
    || fail "host profile: lsr output: ${lsr_block}"
[[ "$(value_of "${out}" FZF_DEFAULT_OPTS)" == "--host-options" \
    && "$(value_of "${out}" FZF_DEFAULT_COMMAND)" == fd* ]] \
    && ok "host profile: the host's FZF_DEFAULT_OPTS is kept, the unset FZF variables get defaults" \
    || fail "host profile: fzf: ${out}"
[[ "$(wc -l < "${INITS}" | tr -d ' ')" -eq 0 \
    && "$(value_of "${out}" PC)" == "starship_precmd title __zoxide_hook __zoxide_hook" \
    && "$(value_of "${out}" SET)" == "true" ]] \
    && ok "host profile: starship is not initialised again, every host hook (the duplicate too) is in place, the prompt is claimed" \
    || fail "host profile: prompt: inits=$(wc -l < "${INITS}") ${out}"

# ── The plain-host twin: nothing set, today's results. ─────────────────────
out="$(run_profile ':' "${REPORT}")"
[[ "$(value_of "${out}" EDITOR)" == "vim" && "$(value_of "${out}" VISUAL)" == "vim" \
    && "$(value_of "${out}" BAT_THEME)" == "Visual Studio Dark+" ]] \
    && ok "plain host: EDITOR and VISUAL are vim, BAT_THEME is workbench's" \
    || fail "plain host: editors: ${out}"
[[ "$(value_of "${out}" LSA)" == *"-Alhi"* && "$(value_of "${out}" LSR)" == *"-Alhitr"* ]] \
    && ok "plain host: lsa and lsr are defined" \
    || fail "plain host: aliases: ${out}"
[[ "$(value_of "${out}" FZF_DEFAULT_OPTS)" == "--height 40% --layout=reverse --border" ]] \
    && ok "plain host: fzf defaults applied" \
    || fail "plain host: fzf: $(value_of "${out}" FZF_DEFAULT_OPTS)"
[[ "$(wc -l < "${INITS}" | tr -d ' ')" -eq 1 && "$(value_of "${out}" PC)" == "starship_precmd" ]] \
    && ok "plain host: starship is initialised once" \
    || fail "plain host: starship: inits=$(wc -l < "${INITS}") PC=$(value_of "${out}" PC)"

echo
if [[ "${FAILED}" -eq 0 ]]; then
    echo "All ${check_no} checks passed."
    exit 0
else
    echo "${FAILED} of ${check_no} checks failed."
    exit 1
fi
