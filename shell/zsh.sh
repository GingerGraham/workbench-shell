#!/usr/bin/env zsh
# shell/zsh.sh — workbench-shell
# Zsh-specific interactive shell configuration.
# Registered at tier: core (workbench.yml), sourced unconditionally —
# self-guards below since workbench-core's tier system has no shell-type
# selector. Must not be sourced in bash — all constructs here are zsh-only.
[[ -z "${ZSH_VERSION}" ]] && return 0

# ── History ───────────────────────────────────────────────────────────────────
HISTFILE="${HOME}/.zsh_history"
HISTSIZE=10000
SAVEHIST=10000
HISTDUP=erase

setopt appendhistory
setopt sharehistory
setopt hist_ignore_space
setopt hist_ignore_all_dups
setopt hist_save_no_dups
setopt hist_ignore_dups
setopt hist_find_no_dups
setopt hist_verify

# ── Completion system ─────────────────────────────────────────────────────────
autoload -Uz compinit
# Regenerate the compinit dump at most once per day to keep startup fast:
# the full check runs when the dump is missing or older than 24 hours
# (glob qualifier N.mh+24), otherwise -C loads the dump as is. The glob is
# expanded in an array assignment because [[ ]] does no filename
# generation. -i drops insecure fpath directories instead of asking about
# them: with no terminal to ask on, compinit would abort and print
# "compinit: initialization aborted".
_wb_zcompdump="${ZDOTDIR:-${HOME}}/.zcompdump"
_wb_zcompdump_stale=( "${_wb_zcompdump}"(N.mh+24) )
if [[ ! -f "${_wb_zcompdump}" || ${#_wb_zcompdump_stale[@]} -gt 0 ]]; then
    compinit -i
else
    compinit -C
fi
unset _wb_zcompdump _wb_zcompdump_stale

zstyle ':completion:*' auto-description 'specify: %d'
zstyle ':completion:*' completer _expand _complete _correct _approximate
zstyle ':completion:*' format 'Completing %d'
zstyle ':completion:*' group-name ''
zstyle ':completion:*' menu select=2
zstyle ':completion:*' list-colors ''
zstyle ':completion:*' list-prompt '%SAt %p: Hit TAB for more, or the character to insert%s'
zstyle ':completion:*' matcher-list '' 'm:{a-z}={A-Z}' 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=* l:|=*'
zstyle ':completion:*' menu select=long
zstyle ':completion:*' select-prompt '%SScrolling active: current selection at %p%s'
zstyle ':completion:*' use-compctl false
zstyle ':completion:*' verbose true
zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#)*=0=01;31'
zstyle ':completion:*:kill:*' command 'ps -u $USER -o pid,%cpu,tty,cputime,cmd'
# Note: ':completion:*:default' list-colors is not set here — it depends on
# LS_COLORS, which is populated by a platform-tier file that loads after
# core (contracts/core-api.md's loader tier order). Set it there instead if
# you want colourised kill-completion output.

# ── Key bindings ──────────────────────────────────────────────────────────────
# Edit the current command line buffer in $EDITOR
autoload -Uz edit-command-line
zle -N edit-command-line
bindkey '^X^E' edit-command-line

# Expand history references on space (e.g. !! becomes the last command)
bindkey ' ' magic-space
# Undo last edit
bindkey '^_' undo

# ── Directory change hook ─────────────────────────────────────────────────────
# List the directory after a cd typed at the prompt (not in the home
# directory). Added to zsh's hook list, so a chpwd of your own still runs.
# Never inside $(…) or a subshell, where the listing would become part of
# captured output (workbench-core D96). BSD ls on macOS has no --color.
_shell_chpwd_list() {
    [[ -o interactive ]] || return 0
    (( ZSH_SUBSHELL == 0 )) || return 0
    [[ "$PWD" != "$HOME" ]] || return 0
    if [[ "${WORKBENCH_OS:-}" == "Mac" ]]; then
        ls -AlhG
    else
        ls -Alh --color=auto
    fi
    return 0
}
typeset -ga chpwd_functions
(( ${chpwd_functions[(I)_shell_chpwd_list]} )) || chpwd_functions+=(_shell_chpwd_list)

log_debug "zsh: shell-specific config loaded"
