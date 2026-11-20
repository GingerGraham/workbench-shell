#!/usr/bin/env bash
# shell/preferences.sh — workbench-shell
# Persisting a preference. Registered at tier: core (workbench.yml), so it
# is loaded before the prompt-engine files in tier: tools that use it.
#
# A preference lives in this module's own overrides file,
#   ${XDG_CONFIG_HOME:-~/.config}/workbench/local/overrides/<name>.sh
# (workbench-core D48), never in a file of this module: those sit inside an
# immutable per-sync snapshot, and an edit there is discarded on the next
# sync. <name> is the name this module is registered under (`wb add <name>`),
# which is what workbench-core names the file after, so it is not assumed to
# be "shell".

# ── Registration name ─────────────────────────────────────────────────────────
# workbench-core registers this file as
#   <modules dir>/<name>/current/shell/preferences.sh
# and gives sourced files no variable holding <name>, so it is read from that
# path, once, while this file is being sourced. A path of any other shape (a
# developer running from a checkout) falls back to "shell".
if [[ -n "${ZSH_VERSION:-}" ]]; then
    # shellcheck disable=SC2296  # zsh's own expansion for "this file"
    _shell_prefs_source="${(%):-%x}"
else
    _shell_prefs_source="${BASH_SOURCE[0]:-}"
fi
_SHELL_MODULE_NAME="shell"
case "${_shell_prefs_source}" in
    */*/current/shell/*)
        _shell_prefs_module_dir="${_shell_prefs_source%/current/shell/*}"
        _shell_prefs_module_name="${_shell_prefs_module_dir##*/}"
        [[ -n "${_shell_prefs_module_name}" ]] && _SHELL_MODULE_NAME="${_shell_prefs_module_name}"
        unset _shell_prefs_module_dir _shell_prefs_module_name
        ;;
esac
unset _shell_prefs_source

# ── Overrides file ────────────────────────────────────────────────────────────
# Prints the path of this module's overrides file.
# WORKBENCH_OVERRIDES_DIR is set by workbench-core's loader.
_shell_overrides_file() {
    printf '%s\n' "${WORKBENCH_OVERRIDES_DIR:-${XDG_CONFIG_HOME:-${HOME}/.config}/workbench/local/overrides}/${_SHELL_MODULE_NAME}.sh"
}

# _shell_override_set <VARIABLE> <value>
# Makes `export VARIABLE="value"` a line of the overrides file: replaces the
# line if there is one, appends it if not. A commented-out example of the
# same variable is not a match and stays as it is. Does not change the
# current shell; callers apply the value themselves where they can.
_shell_override_set() {
    local variable="$1" value="$2" file tmp
    file="$(_shell_overrides_file)"
    mkdir -p "$(dirname "${file}")" || return 1
    touch "${file}" || return 1
    if grep -q "^export ${variable}=" "${file}" 2>/dev/null; then
        tmp="$(mktemp)" || return 1
        # The name and value go in through the environment, not the awk
        # program text: a value is not parsed as awk syntax or sed
        # replacement text, and a backslash or '&' in it is kept as typed.
        _SHELL_OVERRIDE_VAR="${variable}" _SHELL_OVERRIDE_VALUE="${value}" awk '
            index($0, "export " ENVIRON["_SHELL_OVERRIDE_VAR"] "=") == 1 {
                print "export " ENVIRON["_SHELL_OVERRIDE_VAR"] "=\"" ENVIRON["_SHELL_OVERRIDE_VALUE"] "\""
                next
            }
            { print }
        ' "${file}" > "${tmp}" \
            && command cat "${tmp}" > "${file}"
        local rc=$?
        rm -f "${tmp}"
        return "${rc}"
    fi
    printf '\nexport %s="%s"\n' "${variable}" "${value}" >> "${file}"
}

# _shell_override_unset <VARIABLE>
# Removes the `export VARIABLE=...` line from the overrides file. Commented
# lines and everything else stay. Does nothing if there is no such line.
_shell_override_unset() {
    local variable="$1" file tmp rc
    file="$(_shell_overrides_file)"
    [[ -f "${file}" ]] || return 0
    grep -q "^export ${variable}=" "${file}" 2>/dev/null || return 0
    tmp="$(mktemp)" || return 1
    _SHELL_OVERRIDE_VAR="${variable}" awk '
        index($0, "export " ENVIRON["_SHELL_OVERRIDE_VAR"] "=") == 1 { next }
        { print }
    ' "${file}" > "${tmp}" \
        && command cat "${tmp}" > "${file}"
    rc=$?
    rm -f "${tmp}"
    return "${rc}"
}

# ── Prompt engine ─────────────────────────────────────────────────────────────

# Make the choice of prompt engine permanent. Writes
# WORKBENCH_OVERRIDE_PROMPT_ENGINE (see shell/overrides.sh and README.md's
# "Prompt engine election") into this module's overrides file, so the choice
# survives a restart and a module update, and applies it to this shell's
# environment. The new engine starts with `wb reload` or in a new shell.
#   set-prompt-engine omp|starship|omz   force that engine
#   set-prompt-engine none               start no engine (you manage the prompt)
#   set-prompt-engine auto               remove the preference; back to the
#                                        election (omp > starship > omz)
set-prompt-engine() {
    local engine="${1:-}"
    if [[ "${#}" -ne 1 ]]; then
        if [[ "${#}" -eq 0 ]]; then
            log_error "set-prompt-engine: no engine given"
        else
            log_error "set-prompt-engine: expected 1 argument, got ${#}"
        fi
        echo "Usage:   set-prompt-engine <omp|starship|omz|none|auto>"
        echo "Example: set-prompt-engine starship"
        return 1
    fi

    case "${engine}" in
        auto)
            if ! _shell_override_unset WORKBENCH_OVERRIDE_PROMPT_ENGINE; then
                log_error "set-prompt-engine: could not update $(_shell_overrides_file)"
                return 1
            fi
            unset WORKBENCH_OVERRIDE_PROMPT_ENGINE
            log_info "set-prompt-engine: preference removed from $(_shell_overrides_file) — the prompt engine is elected by what is installed"
            ;;
        omp|starship|omz|none)
            # The override falls through to no engine at all when the one
            # named is not installed, so say so rather than leave a bare
            # prompt as a surprise on the next reload.
            case "${engine}" in
                omp)      command -v oh-my-posh >/dev/null 2>&1 || log_warn "set-prompt-engine: oh-my-posh is not installed — the prompt will have no engine until it is (wb tools install oh-my-posh)" ;;
                starship) command -v starship   >/dev/null 2>&1 || log_warn "set-prompt-engine: starship is not installed — the prompt will have no engine until it is (wb tools install starship)" ;;
                omz)      [[ -f "${HOME}/.oh-my-zsh/oh-my-zsh.sh" ]] || log_warn "set-prompt-engine: oh-my-zsh is not installed — the prompt will have no engine until it is (wb tools install oh-my-zsh)" ;;
            esac
            if ! _shell_override_set WORKBENCH_OVERRIDE_PROMPT_ENGINE "${engine}"; then
                log_error "set-prompt-engine: could not write $(_shell_overrides_file)"
                return 1
            fi
            export WORKBENCH_OVERRIDE_PROMPT_ENGINE="${engine}"
            log_info "set-prompt-engine: '${engine}' saved in $(_shell_overrides_file)"
            ;;
        *)
            log_error "set-prompt-engine: unknown engine '${engine}'"
            echo "Valid: omp, starship, omz, none (no engine), auto (back to the election)"
            return 1
            ;;
    esac
    echo "Run 'wb reload' or open a new shell to switch the prompt."
}
