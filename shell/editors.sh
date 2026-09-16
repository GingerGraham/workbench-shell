#!/usr/bin/env bash
# shell/editors.sh — workbench-shell
# Editor environment — sets EDITOR, VISUAL, and related vars. No subprocesses.
# Registered at tier: env (workbench.yml). Ported from
# workbench-precursor's env/10-editors.sh — WORKBENCH_OS (Core API) replaces
# DOTFILES_OS.

# Respect a VISUAL already set upstream (this module's own overrides.sh,
# or workbench-core's settings.sh — both source earlier than tier: env)
# before running the election below. VISUAL already has a natural
# override path (module-authoring.md's "already has an escape hatch"
# case) — no WORKBENCH_OVERRIDE_* needed for it.
#
# Priority: code-insiders/code (GUI sessions only) > nvim > vim. nvim
# isn't GUI-specific, so it's checked regardless of DISPLAY/WAYLAND_DISPLAY
# — it's the fallback for "no GUI editor won, but something better than
# bare vim is installed".
if [[ -z "${VISUAL:-}" ]]; then
    _gui_available=false
    [[ -n "${DISPLAY}" || -n "${WAYLAND_DISPLAY}" || "${WORKBENCH_OS}" == "Mac" ]] && _gui_available=true

    if [[ "${_gui_available}" == "true" ]] && [[ -x "$(command -v code-insiders 2>/dev/null)" ]]; then
        VISUAL="code-insiders --wait"
    elif [[ "${_gui_available}" == "true" ]] && [[ -x "$(command -v code 2>/dev/null)" ]]; then
        VISUAL="code --wait"
    elif [[ -x "$(command -v nvim 2>/dev/null)" ]]; then
        VISUAL="nvim"
    else
        VISUAL="vim"
    fi
    unset _gui_available
fi
export VISUAL

export EDITOR="${EDITOR:-vim}"

# Make less friendlier for non-text input files
export LESS="-R"
export PAGER="${PAGER:-less}"

# ── bat theme ─────────────────────────────────────────────────────────────────
if command -v bat &>/dev/null || command -v batcat &>/dev/null; then
    export BAT_THEME="${BAT_THEME:-Visual Studio Dark+}"
fi

# ── functions ────────────────────────────────────────────────────────────

_open-workspace-available() {
    command -v code &>/dev/null || command -v code-insiders &>/dev/null
}

# Interactively pick and open a *.code-workspace file from a directory
# (default: ~/Development/workspaces). Ported from workbench-precursor's
# core/functions.sh — unchanged apart from the bash-3.2 mapfile fallback,
# which was already there in the donor.
open-workspace() {
    if ! command -v code &>/dev/null && ! command -v code-insiders &>/dev/null; then
        log_error "Visual Studio Code is not installed"
        return 1
    fi

    local workspace_path="${1:-${HOME}/Development/workspaces}"
    local workspaces_full_path=()

    [[ -L "${workspace_path}" ]] && workspace_path="$(readlink -f "${workspace_path}")"

    if [[ -d "${workspace_path}" ]]; then
        if command -v mapfile &>/dev/null; then
            mapfile -t workspaces_full_path < <(find "${workspace_path}" -type f -name "*.code-workspace")
        else
            # shellcheck disable=SC2207
            workspaces_full_path=($(find "${workspace_path}" -type f -name "*.code-workspace"))
        fi
    fi

    if [[ ${#workspaces_full_path[@]} -eq 0 ]]; then
        log_error "No workspaces found in ${workspace_path}"
        return 1
    fi

    local workspaces=()
    for workspace in "${workspaces_full_path[@]}"; do
        workspaces+=("$(basename "${workspace}" .code-workspace)")
    done

    echo "Available workspaces:"
    PS3="Select workspace: "
    select workspace in "${workspaces[@]}"; do
        if [[ -n "${workspace}" ]]; then
            for wsp in "${workspaces_full_path[@]}"; do
                if [[ "${workspace}" == "$(basename "${wsp}" .code-workspace)" ]]; then
                    if command -v code-insiders &>/dev/null; then
                        code-insiders "${wsp}"
                    else
                        code "${wsp}"
                    fi
                    break
                fi
            done
            break
        else
            log_error "Invalid selection, try again"
        fi
    done
}
