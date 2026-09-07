#!/usr/bin/env bash
# shell/bash.sh — workbench-shell
# Bash-specific interactive shell configuration.
# Registered at tier: core (.dotfiles-sync.yml), sourced unconditionally —
# self-guards below since workbench-core's tier system has no shell-type
# selector (only platform/distro filename selectors — contracts/core-api.md).
# Must not contain zsh-specific constructs.
[[ "${WORKBENCH_SHELL}" == "bash" ]] || return 0

# ── History ───────────────────────────────────────────────────────────────────
# Append to the history file on exit rather than overwriting it.
# HISTSIZE/HISTFILESIZE/HISTCONTROL are set by workbench-core's env tier.
shopt -s histappend

# ── Window size ───────────────────────────────────────────────────────────────
# Re-check terminal dimensions after each command so LINES and COLUMNS stay
# accurate after a resize.
shopt -s checkwinsize

# ── Recursive globbing ────────────────────────────────────────────────────────
# Allow ** to match across directory boundaries (bash 4+).
# Silently ignored on bash 3 (macOS system bash) — this is an interactive-shell
# convenience, not part of the bash-3.2-compatible Core API surface, so it's
# fine here (unlike lib/ under workbench-core itself).
shopt -s globstar 2>/dev/null || true

# ── lesspipe ──────────────────────────────────────────────────────────────────
# Allows less to display non-text files (compressed archives, PDFs, etc.)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# ── System bash-completion ────────────────────────────────────────────────────
# Only source if not already loaded and not in posix mode (which disables it).
if ! shopt -oq posix; then
    if [[ -f /usr/share/bash-completion/bash_completion ]]; then
        # shellcheck disable=SC1091
        source /usr/share/bash-completion/bash_completion
    elif [[ -f /etc/bash_completion ]]; then
        # shellcheck disable=SC1091
        source /etc/bash_completion
    fi
fi

# ── asdf bash completions ─────────────────────────────────────────────────────
# The bash completion script is separate from asdf.sh's own shim/PATH init and
# is required for tab completion of asdf subcommands.
if [[ -f "${HOME}/.asdf/completions/asdf.bash" ]]; then
    # shellcheck disable=SC1091
    source "${HOME}/.asdf/completions/asdf.bash"
fi

log_debug "bash: shell-specific config loaded"
