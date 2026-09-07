#!/usr/bin/env bash
# shell/starship.sh — workbench-shell
# starship prompt engine. Registered at tier: tools (.dotfiles-sync.yml),
# sourced unconditionally — self-guards below: skips if oh-my-posh already
# won the prompt-engine election (omp.sh loads first — register order in
# .dotfiles-sync.yml), or if starship itself isn't present.
#
# Uses whatever config is found at $STARSHIP_CONFIG or the XDG default
# (~/.config/starship.toml) — including a pre-existing distro-provided
# config (e.g. Omarchy). This module's own files/starship.toml is deployed
# only if one isn't already present, and never overwritten afterwards
# (.dotfiles-sync.yml's deploy[] force default).
command -v oh-my-posh &>/dev/null && return 0
command -v starship &>/dev/null || return 0

case "${WORKBENCH_SHELL}" in
    bash|zsh)
        eval "$(starship init "${WORKBENCH_SHELL}")"
        ;;
    *)
        log_warn "starship: unsupported shell '${WORKBENCH_SHELL}' — skipping init"
        return 0
        ;;
esac

export WORKBENCH_PROMPT_ENGINE="starship"
export WORKBENCH_PROMPT_SET=true
log_debug "starship: initialised (config: ${STARSHIP_CONFIG:-${XDG_CONFIG_HOME:-${HOME}/.config}/starship.toml})"

# ── functions ────────────────────────────────────────────────────────────────

# Open the active starship config in $EDITOR.
if command -v starship >/dev/null 2>&1; then
    edit-starship-config() {
        local config_file="${STARSHIP_CONFIG:-${XDG_CONFIG_HOME:-${HOME}/.config}/starship.toml}"
        "${EDITOR:-vi}" "${config_file}"
    }
fi
