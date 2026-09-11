#!/usr/bin/env bash
# shell/omp.sh — workbench-shell
# oh-my-posh prompt engine. Registered at tier: tools (workbench.yml),
# sourced unconditionally — self-guards on presence and wins the
# prompt-engine election over starship/oh-my-zsh by loading first (register
# order in workbench.yml). workbench-core's loader has no hardcoded
# prompt-election logic (principle 4) — each prompt-engine file here is
# responsible for its own guard and for setting WORKBENCH_PROMPT_SET=true
# (contracts/core-api.md's prompt-ownership convention) so the loader's own
# fallback PS1/PROMPT is skipped.
command -v oh-my-posh &>/dev/null || return 0

# ── Theme resolution ──────────────────────────────────────────────────────────
# XDG-standard install location used by `oh-my-posh init` and the official
# install script. Fallback for manual ~/bin installs that store themes locally.
OMP_THEME="${OMP_THEME:-atomic}"

if [[ -d "${HOME}/.cache/oh-my-posh/themes" ]]; then
    OMP_THEME_DIR="${HOME}/.cache/oh-my-posh/themes"
elif [[ -d "${HOME}/themes" ]]; then
    OMP_THEME_DIR="${HOME}/themes"
else
    OMP_THEME_DIR=""
    log_warn "oh-my-posh: theme directory not found; falling back to default prompt"
fi

export OMP_THEME OMP_THEME_DIR

# ── Init ──────────────────────────────────────────────────────────────────────
if [[ -n "${OMP_THEME_DIR}" ]] && [[ -f "${OMP_THEME_DIR}/${OMP_THEME}.omp.json" ]]; then
    eval "$(oh-my-posh init "${WORKBENCH_SHELL}" --config "${OMP_THEME_DIR}/${OMP_THEME}.omp.json")"
    log_debug "oh-my-posh: initialised with theme '${OMP_THEME}'"
else
    eval "$(oh-my-posh init "${WORKBENCH_SHELL}")"
    log_debug "oh-my-posh: initialised with built-in default (theme '${OMP_THEME}' not found)"
fi

export WORKBENCH_PROMPT_ENGINE="omp"
export WORKBENCH_PROMPT_SET=true

# ── functions ─────────────────────────────────────────────────────────────────

# List available themes in the terminal with live previews.
omp-themes() {
    if [[ -z "${OMP_THEME_DIR}" ]]; then
        log_error "omp-themes: OMP_THEME_DIR is not set"
        return 1
    fi
    find "${OMP_THEME_DIR}" -maxdepth 1 -type f -name "*.omp.json" | sort | while read -r theme_file; do
        local theme_name
        theme_name="$(basename "${theme_file}" .omp.json)"
        echo ""
        echo "Theme: ${theme_name}"
        oh-my-posh print primary --config "${theme_file}"
        echo ""
    done
}

# Temporarily switch to a different theme in the current session.
set-omp-theme() {
    if [[ -z "${1}" ]]; then
        log_error "set-omp-theme: no theme name provided"
        echo "Usage:   set-omp-theme <theme_name>"
        echo "Example: set-omp-theme jandedobbeleer"
        echo "Themes:  https://ohmyposh.dev/docs/themes  |  omp-themes"
        return 1
    fi
    if [[ "${#}" -gt 1 ]]; then
        log_error "set-omp-theme: expected 1 argument, got ${#}"
        echo "Usage:   set-omp-theme <theme_name>"
        return 1
    fi
    if [[ -z "${OMP_THEME_DIR}" ]]; then
        log_error "set-omp-theme: OMP_THEME_DIR is not set"
        return 1
    fi
    if [[ ! -f "${OMP_THEME_DIR}/${1}.omp.json" ]]; then
        log_error "set-omp-theme: theme '${1}' not found in ${OMP_THEME_DIR}"
        echo "Run 'omp-themes' to list available themes."
        return 1
    fi
    eval "$(oh-my-posh init "${WORKBENCH_SHELL}" --config "${OMP_THEME_DIR}/${1}.omp.json")"
    OMP_THEME="${1}"
    log_debug "oh-my-posh: switched to theme '${1}' for this session"
}

# Permanently update OMP_THEME by exporting it from
# ~/.config/workbench/local/settings.sh (D22's local-overrides file) — NOT by
# editing this file in place. Unlike workbench-precursor (a single persistent
# repo clone), this file lives inside workbench-core's immutable, per-sync
# snapshot (ARCHITECTURE.md principle 6 / §12 D16) — editing it directly
# would be silently discarded on the next sync, and would corrupt the
# sync engine's manifest-hash tracking in the meantime.
set-omp-theme-permanent() {
    if [[ -z "${1}" ]]; then
        log_error "set-omp-theme-permanent: no theme name provided"
        echo "Usage:   set-omp-theme-permanent <theme_name>"
        return 1
    fi
    if [[ "${#}" -gt 1 ]]; then
        log_error "set-omp-theme-permanent: expected 1 argument, got ${#}"
        echo "Usage:   set-omp-theme-permanent <theme_name>"
        return 1
    fi
    if [[ -z "${OMP_THEME_DIR}" ]]; then
        log_error "set-omp-theme-permanent: OMP_THEME_DIR is not set"
        return 1
    fi
    if [[ ! -f "${OMP_THEME_DIR}/${1}.omp.json" ]]; then
        log_error "set-omp-theme-permanent: theme '${1}' not found in ${OMP_THEME_DIR}"
        echo "Run 'omp-themes' to list available themes."
        return 1
    fi

    # Apply in this session
    eval "$(oh-my-posh init "${WORKBENCH_SHELL}" --config "${OMP_THEME_DIR}/${1}.omp.json")"
    OMP_THEME="${1}"

    # Persist: update-or-append an OMP_THEME export in the local overrides file
    local settings_file="${XDG_CONFIG_HOME:-${HOME}/.config}/workbench/local/settings.sh"
    mkdir -p "$(dirname "${settings_file}")"
    touch "${settings_file}"
    if grep -q '^export OMP_THEME=' "${settings_file}" 2>/dev/null; then
        local tmp; tmp="$(mktemp)"
        sed "s/^export OMP_THEME=.*/export OMP_THEME=\"${1}\"/" "${settings_file}" > "${tmp}" \
            && mv "${tmp}" "${settings_file}"
    else
        printf '\nexport OMP_THEME="%s"\n' "${1}" >> "${settings_file}"
    fi
    log_info "oh-my-posh: theme '${1}' set permanently in ${settings_file}"
}
