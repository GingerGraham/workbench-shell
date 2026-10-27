#!/usr/bin/env bash
# shell/aliases.sh — workbench-shell
# Core aliases — general-purpose; registered at tier: core (workbench.yml),
# sourced unconditionally on every shell start. Tool-specific aliases live in
# their own owning module (git/gpg/etc.) guarded by command -v.
# Ported from workbench-precursor's core/aliases.sh, unchanged apart from
# updating the get-installers reference to wb tools (§ below) — no
# get-installers function exists in workbench-core's Core API.

# Availability (workbench-core docs/module-authoring.md). The aliases below
# are defined only when their tool exists, but listings read this file
# statically, so each block declares what it needs.
_shell_have_route_tool() { command -v ip &>/dev/null || command -v netstat &>/dev/null; }
_shell_have_bat()        { command -v bat &>/dev/null || command -v batcat &>/dev/null; }
_shell_have_top()        { command -v btop &>/dev/null || command -v htop &>/dev/null; }
_shell_in_zsh()          { [[ -n "${ZSH_VERSION:-}" ]]; }
_shell_in_bash()         { [[ -n "${BASH_VERSION:-}" && -z "${ZSH_VERSION:-}" ]]; }
_shell_have_ip_lookup()  { command -v dig &>/dev/null || command -v curl &>/dev/null; }
_shell_have_get_functions() { command -v get-functions &>/dev/null; }
_wb_alias_availability --needs "ip (iproute2) or netstat" _shell_have_route_tool routeprint printrt
_wb_alias_availability --needs "bat (bat or batcat)"      _shell_have_bat cat
_wb_alias_availability --needs "btop or htop"             _shell_have_top top
_wb_alias_availability --needs "zsh (the current shell)"  _shell_in_zsh zshconfig zshreload history
_wb_alias_availability --needs "bash (the current shell)" _shell_in_bash bashconfig bashreload
_wb_alias_availability --needs "dig or curl"              _shell_have_ip_lookup get-public-ip
_wb_alias_availability --needs "workbench-core's get-functions" _shell_have_get_functions aliases reset-shell rs
_wb_declare_availability ssh-add       sshclear
_wb_declare_availability batcat        bat
_wb_declare_availability python3       python get-python-versions
_wb_declare_availability pip3          pip
_wb_declare_availability acpi          battery power
_wb_declare_availability tmux          tmux-new tmux-attach tmux-reload
_wb_declare_availability code-insiders code
_wb_declare_availability wl-copy       copy clip
_wb_declare_availability nautilus      explorer
_wb_declare_availability nordvpn       nordc nordd
_wb_declare_availability cmatrix       matrix
_wb_declare_availability it2profile    solarized black smooth
_wb_declare_availability wb            installers
# open-workspace is shell/editors.sh's, with a hand-written predicate there.
# Its needs text goes here: editors.sh is tier env, which loads before core
# defines _wb_availability_needs (Core API, tier core).
_wb_availability_needs "VS Code (code or code-insiders)" open-workspace

# ── Filesystem ────────────────────────────────────────────────────────────────
alias lsa="ls -Alhi"
alias lsr="ls -Alhitr"
alias dirsize="du -sh"
alias cls="clear"

# ── Network diagnostics ───────────────────────────────────────────────────────
# The routing table: ip route (iproute2) on Linux, netstat -rn on macOS and
# anywhere without ip. Not ss -rn, which lists sockets, not routes.
if [[ "${WORKBENCH_OS:-}" != "Mac" ]] && command -v ip &>/dev/null; then
    alias routeprint="ip route"
    alias printrt="ip route"
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
# if-blocks, not `command -v … && alias`: listings find an alias only at
# the start of a line.
if command -v python3 &>/dev/null; then
    alias python="python3"
fi
if command -v pip3 &>/dev/null; then
    alias pip="pip3"
fi

# ── acpi power ────────────────────────────────────────────────────────────────
if command -v acpi &>/dev/null; then
    alias battery="acpi -bi"
    alias power="acpi -a"
fi

# ── Tmux ──────────────────────────────────────────────────────────────────────
if command -v tmux &>/dev/null; then
    alias tmux-new='tmux new-session -s main'
    alias tmux-attach='tmux attach-session -t main'
    # Reload the config tmux reads: the first that exists in tmux's own
    # search order. Your file holds workbench's block (workbench-core D82),
    # so this reloads both. Defined with 'function': a shell that already
    # has 0.7.x's tmux-reload alias would expand it in 'tmux-reload()' and
    # fail to parse; neither bash nor zsh expands the name after 'function'.
    # The unalias then stops that old alias shadowing the function.
    unalias tmux-reload 2>/dev/null || true
    function tmux-reload {
        local conf
        for conf in "${HOME}/.tmux.conf" \
                    "${XDG_CONFIG_HOME:-${HOME}/.config}/tmux/tmux.conf" \
                    "${HOME}/.config/tmux/tmux.conf"; do
            if [[ -f "${conf}" ]]; then
                tmux source-file "${conf}"
                return
            fi
        done
        log_error "tmux-reload: no tmux config found (~/.tmux.conf or ~/.config/tmux/tmux.conf)"
        return 1
    }
fi

# ── VS Code ───────────────────────────────────────────────────────────────────
if command -v code-insiders &>/dev/null; then
    alias code="code-insiders"
fi

# ── Clipboard (Wayland) ───────────────────────────────────────────────────────
if command -v wl-copy &>/dev/null; then
    alias copy="wl-copy"
    alias clip="wl-copy"
fi

# ── File manager ──────────────────────────────────────────────────────────────
if command -v nautilus &>/dev/null; then
    alias explorer="nautilus --browser &"
fi

# ── VPN ───────────────────────────────────────────────────────────────────────
if command -v nordvpn &>/dev/null; then
    alias nordc="nordvpn connect"
    alias nordd="nordvpn disconnect"
fi

# ── Fun ───────────────────────────────────────────────────────────────────────
if command -v cmatrix &>/dev/null; then
    alias matrix="cmatrix -abs"
fi

# ── get-functions shortcut ────────────────────────────────────────────────────
# reset-shell/rs are meant to redisplay the same quick summary a fresh
# shell already shows you (WORKBENCH_SHOW_FUNCTIONS's startup banner,
# workbench-core lib/loader.sh) — --no-pager --no-aliases matches that
# banner exactly, so these never drop into an interactive pager session
# or dump the full aliases listing (workbench-core docs/decisions-log.md
# D73; real report: reset-shell paged and showed a much narrower column
# layout than `wb apply`/a new terminal, once workbench-core's `wb
# functions` gained a pager). `aliases` is left as a bare `get-functions`
# call, unchanged — its whole purpose is the full listing, aliases
# included, same as running `wb functions` by hand.
if command -v get-functions &>/dev/null; then
    alias aliases="get-functions"
    alias reset-shell="clear && get-functions --no-pager --no-aliases"
    alias rs="clear && get-functions --no-pager --no-aliases"
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
if _shell_in_zsh; then
    alias zshconfig='${VISUAL:-vim} "${HOME}/.zshrc"'
    alias zshreload="exec zsh"
    alias history="history 1"
fi

if _shell_in_bash; then
    alias bashconfig='${VISUAL:-vim} "${HOME}/.bashrc"'
    alias bashreload="exec bash"
fi

# ── functions ────────────────────────────────────────────────────────────

# List installed Python 3.x interpreters and their versions. find, not a
# /usr/bin/python3* glob: an unmatched glob is an error in zsh and a
# literal in bash.
get-python-versions() {
    log_info "Python versions found:"
    local version
    find /usr/bin /usr/local/bin -maxdepth 1 -type f -name 'python3*' ! -name '*-config' 2>/dev/null \
        | sort \
        | while IFS= read -r version; do
            echo "$(basename "${version}"): $("${version}" --version 2>&1)"
        done
}

# Public IPv4/IPv6 lookup — dig if available, curl (icanhazip.com)
# otherwise. curl -f: an HTTP error page isn't printed as an address.
get-public-ip() {
    if command -v dig &>/dev/null; then
        echo "IPv4: $(dig -4 TXT +short o-o.myaddr.l.google.com @ns1.google.com | awk -F'"' '{print $2}')"
        echo "IPv6: $(dig -6 TXT +short o-o.myaddr.l.google.com @ns1.google.com | awk -F'"' '{print $2}')"
    else
        echo "IPv4: $(curl -fsS https://ipv4.icanhazip.com)"
        echo "IPv6: $(curl -fsS https://ipv6.icanhazip.com)"
    fi
}
