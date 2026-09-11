#!/usr/bin/env bash
# shell/fzf.sh — workbench-shell
# fzf configuration — shell integration, default options, and fd-backed
# commands. Registered at tier: tools (workbench.yml), sourced
# unconditionally — self-guards on `command -v fzf`. Shell-aware: uses
# fzf --zsh or fzf --bash depending on WORKBENCH_SHELL.

# ── Shell integration ─────────────────────────────────────────────────────────
# Loads Ctrl-R (history), Ctrl-T (file picker), and Alt-C (directory jump)
# key bindings plus fuzzy tab completion.
if [[ "${WORKBENCH_SHELL}" == "zsh" ]]; then
    # shellcheck disable=SC1090
    source <(fzf --zsh 2>/dev/null) || true
elif [[ "${WORKBENCH_SHELL}" == "bash" ]]; then
    # shellcheck disable=SC1090
    source <(fzf --bash 2>/dev/null) || true
fi

# ── Default display options ───────────────────────────────────────────────────
export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border'

# ── Default command — prefer fd for speed and .gitignore awareness ────────────
if command -v fd &>/dev/null; then
    export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
    export FZF_CTRL_T_COMMAND="${FZF_DEFAULT_COMMAND}"
    export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
fi

# ── Preview — use bat/batcat for syntax-highlighted file previews ─────────────
if command -v bat &>/dev/null; then
    export FZF_CTRL_T_OPTS="--preview 'bat --color=always --style=header,grid --line-range :500 {}'"
elif command -v batcat &>/dev/null; then
    export FZF_CTRL_T_OPTS="--preview 'batcat --color=always --style=header,grid --line-range :500 {}'"
fi

log_debug "fzf: integration loaded (shell=${WORKBENCH_SHELL})"
