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
