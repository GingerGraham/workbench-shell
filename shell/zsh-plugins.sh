#!/usr/bin/env zsh
# shell/zsh-plugins.sh — workbench-shell
# Zsh plugins — autosuggestions and syntax highlighting. Registered at tier:
# tools (workbench.yml), sourced unconditionally — self-guards on
# ZSH_VERSION.
#
# Plugin resolution order (first <plugin>.zsh that exists wins):
#   1. ~/.zsh/<plugin>/                                     manual install
#   2. ${XDG_DATA_HOME:-~/.local/share}/zsh/plugins/<plugin>/
#                                    wb tools install zsh-plugins (git clone)
#   3. /usr/share/<plugin>/                                 dnf/apt/zypper
#   4. /usr/share/zsh/plugins/<plugin>/                     Arch (pacman)
#   5. ${HOMEBREW_PREFIX:-/opt/homebrew}/share/<plugin>/,
#      then /usr/local/share/<plugin>/                      Homebrew
#   6. ~/.oh-my-zsh/custom/plugins/<plugin>/                OMZ-managed
# Homebrew's prefix is never asked of brew: no subprocess at shell start.
#
# zsh-syntax-highlighting MUST be sourced last — it wraps the zle widgets
# set up by compinit and autosuggestions. Changing this order breaks both.
[[ -z "${ZSH_VERSION}" ]] && return 0

# _zsh_plugin_path <plugin>
# Sets _zsh_plugin_path_result to the first file above that exists, or
# returns 1. The same list is in shell/installers.sh (_zsh_plugin_path,
# for installed-zsh-plugins): change both together.
_zsh_plugin_path() {
    local _p="$1" _f
    _zsh_plugin_path_result=""
    for _f in "${HOME}/.zsh/${_p}/${_p}.zsh" \
              "${XDG_DATA_HOME:-${HOME}/.local/share}/zsh/plugins/${_p}/${_p}.zsh" \
              "/usr/share/${_p}/${_p}.zsh" \
              "/usr/share/zsh/plugins/${_p}/${_p}.zsh" \
              "${HOMEBREW_PREFIX:-/opt/homebrew}/share/${_p}/${_p}.zsh" \
              "/usr/local/share/${_p}/${_p}.zsh" \
              "${HOME}/.oh-my-zsh/custom/plugins/${_p}/${_p}.plugin.zsh"; do
        if [[ -f "${_f}" ]]; then
            _zsh_plugin_path_result="${_f}"
            return 0
        fi
    done
    return 1
}

# _zsh_plugin_source <plugin>
# Sources the plugin from the first path above that exists; returns 1 when
# none does. Debug, not a warning, when missing: an optional plugin is not
# worth a line on every shell start (workbench-core docs/decisions-log.md
# D94).
_zsh_plugin_source() {
    if _zsh_plugin_path "$1"; then
        # shellcheck disable=SC1090
        source "${_zsh_plugin_path_result}"
        log_debug "zsh-plugins: $1 loaded from ${_zsh_plugin_path_result}"
        return 0
    fi
    log_debug "zsh-plugins: $1 not found — 'wb tools install zsh-plugins', or clone to ~/.zsh/$1/"
    return 1
}

# ── zsh-autosuggestions ───────────────────────────────────────────────────────
if _zsh_plugin_source zsh-autosuggestions; then
    ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#c6c6c6"
    ZSH_AUTOSUGGEST_STRATEGY=(history completion)
fi

# ── zsh-syntax-highlighting ───────────────────────────────────────────────────
# Source LAST — wraps ZLE widgets installed by everything above.
_zsh_plugin_source zsh-syntax-highlighting
unset _zsh_plugin_path_result
