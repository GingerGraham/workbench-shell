#!/usr/bin/env bash
# shell/aliases.sh — workbench-shell
# Core aliases — general-purpose; registered at tier: core (.dotfiles-sync.yml),
# sourced unconditionally on every shell start. Tool-specific aliases live in
# their own owning module (git/gpg/etc.) guarded by command -v.
# Ported from workbench-precursor's core/aliases.sh, unchanged apart from
# updating the get-installers reference to wb tools (§ below) — no
# get-installers function exists in workbench-core's Core API.

# ── Filesystem ────────────────────────────────────────────────────────────────
alias lsa="ls -Alhi"
alias lsr="ls -Alhitr"
alias dirsize="du -sh"
alias cls="clear"

# ── Network diagnostics ───────────────────────────────────────────────────────
# Prefer ss (iproute2, standard on modern Linux) over the deprecated netstat.
# Fall back to netstat for macOS and any system without ss.
if command -v ss &>/dev/null; then
    alias routeprint="ss -rn"
    alias printrt="ss -rn"
elif command -v netstat &>/dev/null; then
    alias routeprint="netstat -rn"
    alias printrt="netstat -rn"
fi

# ── SSH agent ─────────────────────────────────────────────────────────────────
alias sshclear="ssh-add -D"

# ── Better cat/bat ────────────────────────────────────────────────────────────
if command -v batcat &>/dev/null; then
    alias cat="batcat -p"
    alias bat="batcat"
elif command -v bat &>/dev/null; then
    alias cat="bat -p"
fi

# ── Better top ────────────────────────────────────────────────────────────────
if command -v btop &>/dev/null; then
    alias top="btop"
elif command -v htop &>/dev/null; then
    alias top="htop"
fi

# ── Python ────────────────────────────────────────────────────────────────────
command -v python3 &>/dev/null && alias python="python3"
command -v pip3    &>/dev/null && alias pip="pip3"

# ── acpi power ────────────────────────────────────────────────────────────────
if command -v acpi &>/dev/null; then
    alias battery="acpi -bi"
    alias power="acpi -a"
fi

# ── Tmux ──────────────────────────────────────────────────────────────────────
if command -v tmux &>/dev/null; then
    alias tmux-new='tmux new-session -s main'
    alias tmux-attach='tmux attach-session -t main'
    alias tmux-reload='tmux source-file "${HOME}/.config/tmux/tmux.conf"'
fi

# ── VS Code ───────────────────────────────────────────────────────────────────
command -v code-insiders &>/dev/null && alias code="code-insiders"

# ── Clipboard (Wayland) ───────────────────────────────────────────────────────
if command -v wl-copy &>/dev/null; then
    alias copy="wl-copy"
    alias clip="wl-copy"
fi

# ── File manager ──────────────────────────────────────────────────────────────
command -v nautilus &>/dev/null && alias explorer="nautilus --browser &"

# ── VPN ───────────────────────────────────────────────────────────────────────
if command -v nordvpn &>/dev/null; then
    alias nordc="nordvpn connect"
    alias nordd="nordvpn disconnect"
fi

# ── Fun ───────────────────────────────────────────────────────────────────────
command -v cmatrix &>/dev/null && alias matrix="cmatrix -abs"

# ── get-functions shortcut ────────────────────────────────────────────────────
if command -v get-functions &>/dev/null; then
    alias aliases="get-functions"
    alias reset-shell="clear && get-functions"
    alias rs="clear && get-functions"
fi

# ── wb tools shortcut ─────────────────────────────────────────────────────────
if command -v wb &>/dev/null; then
    alias installers="wb tools list"
fi

# ── SSH hosts ─────────────────────────────────────────────────────────────────
# If list-ssh-hosts is defined (workbench-ssh), use it; otherwise fall back to
# a simple grep.
if declare -f list-ssh-hosts &>/dev/null; then
    alias sshhosts="list-ssh-hosts"
else
    alias sshhosts='grep -E "^Host\s" "${HOME}/.ssh/config"'
fi

# ── iTerm2 ────────────────────────────────────────────────────────────────────
if command -v it2profile &>/dev/null; then
    alias solarized="it2profile -s Solarized"
    alias black="it2profile -s Black"
    alias smooth="it2profile -s Smooth"
fi

# ── Shell-specific ────────────────────────────────────────────────────────────
if [[ -n "${ZSH_VERSION}" ]]; then
    alias zshconfig='${VISUAL:-vim} "${HOME}/.zshrc"'
    alias zshreload="exec zsh"
    alias history="history 1"
fi

if [[ -n "${BASH_VERSION}" ]]; then
    alias bashconfig='${VISUAL:-vim} "${HOME}/.bashrc"'
    alias bashreload="exec bash"
fi

get-shell-functions() {
    local _dir; _dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local -a _files=(
        "${_dir}/aliases.sh" "${_dir}/bash.sh" "${_dir}/zsh.sh"
        "${_dir}/omp.sh" "${_dir}/starship.sh" "${_dir}/omz.sh"
        "${_dir}/zsh-plugins.sh" "${_dir}/direnv.sh" "${_dir}/fzf.sh"
        "${_dir}/editors.sh"
    )
    # installers.sh is deliberately excluded — its install-* functions are
    # surfaced via `wb tools list`, not this getter.
    _get_functions_in "Shell functions" "" "${_files[@]}"
    _get_aliases_in "Shell aliases" "" "${_files[@]}"
}
