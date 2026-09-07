#!/usr/bin/env bash
# shell/omz.sh — workbench-shell
# oh-my-zsh prompt/framework. Registered at tier: tools (.dotfiles-sync.yml),
# sourced unconditionally — self-guards below: only proceeds when oh-my-posh
# and starship both lost the prompt-engine election (they load first —
# register order in .dotfiles-sync.yml), ~/.oh-my-zsh exists, and the
# current shell is zsh. bash-sourcing this file is a no-op.
[[ -z "${ZSH_VERSION}" ]] && return 0
command -v oh-my-posh &>/dev/null && return 0
command -v starship &>/dev/null && return 0
[[ -d "${HOME}/.oh-my-zsh" ]] || return 0

# ── Core paths ────────────────────────────────────────────────────────────────
export ZSH="${HOME}/.oh-my-zsh"

# ── Theme ─────────────────────────────────────────────────────────────────────
ZSH_THEME="jonathan"

# ── Update behaviour ──────────────────────────────────────────────────────────
zstyle ':omz:update' mode auto
zstyle ':omz:update' frequency 7

# ── History ───────────────────────────────────────────────────────────────────
HISTCONTROL=ignoreboth
# shellcheck disable=SC2034
HIST_STAMPS="yyyy-mm-dd"

# ── UX ────────────────────────────────────────────────────────────────────────
# shellcheck disable=SC2034
ENABLE_CORRECTION="true"
# shellcheck disable=SC2034
COMPLETION_WAITING_DOTS="true"

# ── Plugins ───────────────────────────────────────────────────────────────────
# Keep this list minimal — each plugin adds startup time.
# Tool-specific completions live alongside their owning module and load
# separately (e.g. workbench-git's shell/completions/{gh,glab}.sh).
# shellcheck disable=SC2034
plugins=(
    aliases
    git
    kubectl
    terraform
)

# ── Init ──────────────────────────────────────────────────────────────────────
# shellcheck disable=SC1091
source "${ZSH}/oh-my-zsh.sh"
log_debug "oh-my-zsh: initialised with theme '${ZSH_THEME}'"

export WORKBENCH_PROMPT_ENGINE="omz"
export WORKBENCH_PROMPT_SET=true
