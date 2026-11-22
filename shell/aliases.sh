#!/usr/bin/env bash
# shell/aliases.sh — workbench-shell
# Core aliases — general-purpose; registered at tier: core (workbench.yml),
# sourced unconditionally on every shell start. Tool-specific aliases live in
# their own owning module (git/gpg/etc.) guarded by command -v.
# Ported from workbench-precursor's core/aliases.sh, unchanged apart from
# updating the get-installers reference to wb tools (§ below) — no
# get-installers function exists in workbench-core's Core API.

# Availability (workbench-core docs/guide/module-authoring.md). The aliases below
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
_wb_alias_availability --needs "zsh (the current shell)"  _shell_in_zsh zshconfig zshreload zshsource history
_wb_alias_availability --needs "bash (the current shell)" _shell_in_bash bashconfig bashreload bashsource
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

# ── Aliases yield to what is already there (workbench-core D124) ─────────────
# workbench never replaces an alias or function it did not define. Every alias
# below goes through workbench_alias_define (Core API 1.10): a name that is
# already an alias or a function, and that workbench did not set, is the
# host's (a distribution's profile, your own rc file) and is left alone. The
# loader says so once, and `wb status` lists it. A name workbench defined
# earlier in this shell is redefined, so a reload refreshes it.
#
# Each call starts its line, inside an `if` block where it is conditional,
# not after `&&`: workbench's listings find a name only at the start of a
# line.

# GNU ls takes --color=auto; BSD ls (macOS) does not and uses -G. lsa and lsr
# call `command ls` so a user's own `ls` alias (eza, say) cannot change what
# they mean, and that also skips the colour a plain `ls` alias would have
# added, so ask for it here where it is supported.
_shell_ls_color=""
command ls --color=auto -d . >/dev/null 2>&1 && _shell_ls_color="--color=auto "

# ── Filesystem ────────────────────────────────────────────────────────────────
workbench_alias_define lsa shell "command ls ${_shell_ls_color}-Alhi"
workbench_alias_define lsr shell "command ls ${_shell_ls_color}-Alhitr"
workbench_alias_define dirsize shell "du -sh"
workbench_alias_define cls shell "clear"

# ── Network diagnostics ───────────────────────────────────────────────────────
# The routing table: ip route (iproute2) on Linux, netstat -rn on macOS and
# anywhere without ip. Not ss -rn, which lists sockets, not routes.
if [[ "${WORKBENCH_OS:-}" != "Mac" ]] && command -v ip &>/dev/null; then
    workbench_alias_define routeprint shell "ip route"
    workbench_alias_define printrt shell "ip route"
elif command -v netstat &>/dev/null; then
    workbench_alias_define routeprint shell "netstat -rn"
    workbench_alias_define printrt shell "netstat -rn"
fi

# ── SSH agent ─────────────────────────────────────────────────────────────────
workbench_alias_define sshclear shell "ssh-add -D"

# ── Better cat/bat ────────────────────────────────────────────────────────────
if command -v batcat &>/dev/null; then
    workbench_alias_define cat shell "batcat -p"
    workbench_alias_define bat shell "batcat"
elif command -v bat &>/dev/null; then
    workbench_alias_define cat shell "bat -p"
fi

# ── Better top ────────────────────────────────────────────────────────────────
if command -v btop &>/dev/null; then
    workbench_alias_define top shell "btop"
elif command -v htop &>/dev/null; then
    workbench_alias_define top shell "htop"
fi

# ── Python ────────────────────────────────────────────────────────────────────
# if-blocks, not `command -v … && alias`: listings find an alias only at
# the start of a line.
if command -v python3 &>/dev/null; then
    workbench_alias_define python shell "python3"
fi
if command -v pip3 &>/dev/null; then
    workbench_alias_define pip shell "pip3"
fi

# ── acpi power ────────────────────────────────────────────────────────────────
if command -v acpi &>/dev/null; then
    workbench_alias_define battery shell "acpi -bi"
    workbench_alias_define power shell "acpi -a"
fi

# ── Tmux ──────────────────────────────────────────────────────────────────────
if command -v tmux &>/dev/null; then
    workbench_alias_define tmux-new shell 'tmux new-session -s main'
    workbench_alias_define tmux-attach shell 'tmux attach-session -t main'
    # Reload the config tmux reads: the first that exists in tmux's own
    # search order. Your file holds workbench's block (workbench-core D82),
    # so this reloads both. Defined with 'function': a shell that already
    # has 0.7.x's tmux-reload alias would expand it in 'tmux-reload()' and
    # fail to parse; neither bash nor zsh expands the name after 'function'.
    # The unalias then stops that old alias shadowing the function. It removes
    # only an alias workbench defined, or 0.7.x's own text, never a host's
    # alias of the name.
    _shell_old_tmux_reload="$(alias tmux-reload 2>/dev/null)"
    if workbench_alias_is_ours tmux-reload; then
        unalias tmux-reload 2>/dev/null || true
    else
        # shellcheck disable=SC2016  # matching 0.7.x's alias text literally
        case "${_shell_old_tmux_reload}" in
            *'tmux source-file "${HOME}/.config/tmux/tmux.conf"'*) unalias tmux-reload 2>/dev/null || true ;;
        esac
    fi
    unset _shell_old_tmux_reload
    # A function, so it cannot go through workbench_alias_define; it yields by
    # hand, the same way. Defined when no alias or function of the name exists,
    # or when it is the function this file defined earlier in this shell
    # (_SHELL_TMUX_RELOAD_OURS survives a reload, as module variables do). A
    # host's alias or function of the name is left in place.
    if ! alias tmux-reload >/dev/null 2>&1 \
        && { [[ "${_SHELL_TMUX_RELOAD_OURS:-}" == "yes" ]] || ! typeset -f tmux-reload >/dev/null 2>&1; }; then
        _SHELL_TMUX_RELOAD_OURS=yes
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
fi

# ── VS Code ───────────────────────────────────────────────────────────────────
if command -v code-insiders &>/dev/null; then
    workbench_alias_define code shell "code-insiders"
fi

# ── Clipboard (Wayland) ───────────────────────────────────────────────────────
if command -v wl-copy &>/dev/null; then
    workbench_alias_define copy shell "wl-copy"
    workbench_alias_define clip shell "wl-copy"
fi

# ── File manager ──────────────────────────────────────────────────────────────
if command -v nautilus &>/dev/null; then
    workbench_alias_define explorer shell "nautilus --browser &"
fi

# ── VPN ───────────────────────────────────────────────────────────────────────
if command -v nordvpn &>/dev/null; then
    workbench_alias_define nordc shell "nordvpn connect"
    workbench_alias_define nordd shell "nordvpn disconnect"
fi

# ── Fun ───────────────────────────────────────────────────────────────────────
if command -v cmatrix &>/dev/null; then
    workbench_alias_define matrix shell "cmatrix -abs"
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
    workbench_alias_define aliases shell "get-functions"
    workbench_alias_define reset-shell shell "clear && get-functions --no-pager --no-aliases"
    workbench_alias_define rs shell "clear && get-functions --no-pager --no-aliases"
fi

# ── wb tools shortcut ─────────────────────────────────────────────────────────
if command -v wb &>/dev/null; then
    workbench_alias_define installers shell "wb tools list"
fi

# ── SSH hosts ─────────────────────────────────────────────────────────────────
# If list-ssh-hosts is defined (workbench-ssh), use it; otherwise fall back to
# a simple grep.
if declare -f list-ssh-hosts &>/dev/null; then
    workbench_alias_define sshhosts shell "list-ssh-hosts"
else
    # shellcheck disable=SC2016  # expands when the alias runs, not now
    workbench_alias_define sshhosts shell 'grep -E "^Host\s" "${HOME}/.ssh/config"'
fi

# ── iTerm2 ────────────────────────────────────────────────────────────────────
if command -v it2profile &>/dev/null; then
    workbench_alias_define solarized shell "it2profile -s Solarized"
    workbench_alias_define black shell "it2profile -s Black"
    workbench_alias_define smooth shell "it2profile -s Smooth"
fi

# ── Shell-specific ────────────────────────────────────────────────────────────
if _shell_in_zsh; then
    # shellcheck disable=SC2016  # expands when the alias runs, not now
    workbench_alias_define zshconfig shell '${VISUAL:-vim} "${HOME}/.zshrc"'
    workbench_alias_define zshreload shell "exec zsh"
    # Re-read ~/.zshrc in the current shell. zshreload starts a new zsh
    # instead; this keeps the session's own variables and history.
    # shellcheck disable=SC2016  # expands when the alias runs, not now
    workbench_alias_define zshsource shell 'source "${HOME}/.zshrc"'
    workbench_alias_define history shell "history 1"
fi

if _shell_in_bash; then
    # shellcheck disable=SC2016  # expands when the alias runs, not now
    workbench_alias_define bashconfig shell '${VISUAL:-vim} "${HOME}/.bashrc"'
    workbench_alias_define bashreload shell "exec bash"
    # Re-read ~/.bashrc in the current shell. bashreload starts a new bash
    # instead; this keeps the session's own variables and history.
    # shellcheck disable=SC2016  # expands when the alias runs, not now
    workbench_alias_define bashsource shell 'source "${HOME}/.bashrc"'
fi

# ── functions ────────────────────────────────────────────────────────────

# List installed Python 3.x interpreters and their versions. find, not a
# /usr/bin/python3* glob: an unmatched glob is an error in zsh and a
# literal in bash.
get-python-versions() {
    log_info "Python versions found:"
    local version
    command find /usr/bin /usr/local/bin -maxdepth 1 -type f -name 'python3*' ! -name '*-config' 2>/dev/null \
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
