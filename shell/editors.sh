#!/usr/bin/env bash
# shell/editors.sh — workbench-shell
# Editor environment — sets EDITOR, VISUAL, and related vars. No subprocesses.
# Registered at tier: env (workbench.yml). Ported from
# workbench-precursor's env/10-editors.sh — WORKBENCH_OS (Core API) replaces
# DOTFILES_OS.

if [[ -n "${DISPLAY}" || -n "${WAYLAND_DISPLAY}" || "${WORKBENCH_OS}" == "Mac" ]]; then
    # Prefer code/code-insiders when a display is available
    if [[ -x "$(command -v code-insiders 2>/dev/null)" ]]; then
        export VISUAL="code-insiders --wait"
    elif [[ -x "$(command -v code 2>/dev/null)" ]]; then
        export VISUAL="code --wait"
    else
        export VISUAL="${VISUAL:-vim}"
    fi
else
    export VISUAL="${VISUAL:-vim}"
fi

export EDITOR="${EDITOR:-vim}"

# Make less friendlier for non-text input files
export LESS="-R"
export PAGER="${PAGER:-less}"

# ── bat theme ─────────────────────────────────────────────────────────────────
if command -v bat &>/dev/null || command -v batcat &>/dev/null; then
    export BAT_THEME="${BAT_THEME:-Visual Studio Dark+}"
fi
