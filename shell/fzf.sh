#!/usr/bin/env bash
# shell/fzf.sh — workbench-shell
# fzf configuration — shell integration, default options, and fd-backed
# commands. Registered at tier: tools (workbench.yml), sourced
# unconditionally — self-guards on `command -v fzf`. Shell-aware: uses
# fzf --zsh or fzf --bash depending on WORKBENCH_SHELL.

# ── Shell integration ─────────────────────────────────────────────────────────
# Loads Ctrl-R (history), Ctrl-T (file picker), and Alt-C (directory jump)
# key bindings plus fuzzy tab completion. Without fzf, nothing is evaluated:
# the output of whatever ran instead would be, and on Ubuntu bash's
# command-not-found handler prints a line starting "Please" that bash then
# ran as a command (workbench-core D94). eval of captured output, not
# source <(…): bash 3.2 (macOS) sources nothing from a process substitution.
if ! command -v fzf &>/dev/null; then
    log_debug "fzf: not installed — shell integration skipped (wb tools install fzf)"
elif [[ "${WORKBENCH_SHELL}" == "zsh" || "${WORKBENCH_SHELL}" == "bash" ]]; then
    # fzf --bash / --zsh need fzf 0.48.0+. Older builds exit non-zero and
    # print nothing on stdout, which evaluating it as before treated as
    # success — the integration was silently skipped. Capture first,
    # evaluate only real output, and say so when there is none.
    _wb_fzf_init="$(fzf "--${WORKBENCH_SHELL}" 2>/dev/null)"
    if [[ -n "${_wb_fzf_init}" ]]; then
        eval "${_wb_fzf_init}"
    elif [[ $- == *i* ]]; then
        log_warn "fzf: $(fzf --version 2>/dev/null | cut -d' ' -f1) is too old for shell integration (needs 0.48.0+) — Ctrl-R/Ctrl-T/Alt-C not bound. Fix: wb tools upgrade fzf"
    fi
    unset _wb_fzf_init
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
