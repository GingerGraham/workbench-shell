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

# ── Aliases yield to what is already there (workbench-core D110) ─────────────
# workbench changes only state it created. A name that is already an alias
# or a function and that this file did not define is the host's (a
# distribution's profile, your own rc file) and is left alone. A name this
# file defined earlier in this shell is redefined, so a reload refreshes it.
#
# Each definition below is written as
#     if _shell_alias_free NAME; then
#         alias NAME=...
#     fi
# rather than `_shell_alias_free NAME && alias NAME=...`: workbench's
# listings find an alias only at the start of a line.
#
# _SHELL_ALIASES_OURS lists the names this file has defined. Nothing in the
# loader clears module variables between passes, so it survives a reload.
# Works the same in bash and zsh: `alias NAME` and `typeset -f NAME` both
# behave alike in each.
_SHELL_ALIASES_OURS="${_SHELL_ALIASES_OURS:-}"

_shell_alias_free() {
    local name="$1"
    case " ${_SHELL_ALIASES_OURS} " in
        *" ${name} "*) return 0 ;;
    esac
    alias "${name}" >/dev/null 2>&1 && return 1
    typeset -f "${name}" >/dev/null 2>&1 && return 1
    _SHELL_ALIASES_OURS="${_SHELL_ALIASES_OURS} ${name}"
    return 0
}

# GNU ls takes --color=auto; BSD ls (macOS) does not and uses -G. lsa and lsr
# call `command ls` so a user's own `ls` alias (eza, say) cannot change what
# they mean, and that also skips the colour a plain `ls` alias would have
# added, so ask for it here where it is supported.
_shell_ls_color=""
command ls --color=auto -d . >/dev/null 2>&1 && _shell_ls_color="--color=auto "

# ── Filesystem ────────────────────────────────────────────────────────────────
if _shell_alias_free lsa; then
    # shellcheck disable=SC2139  # the colour flag is meant to expand now
    alias lsa="command ls ${_shell_ls_color}-Alhi"
fi
if _shell_alias_free lsr; then
    # shellcheck disable=SC2139  # the colour flag is meant to expand now
    alias lsr="command ls ${_shell_ls_color}-Alhitr"
fi
if _shell_alias_free dirsize; then
    alias dirsize="du -sh"
fi
if _shell_alias_free cls; then
    alias cls="clear"
fi

# ── Network diagnostics ───────────────────────────────────────────────────────
# The routing table: ip route (iproute2) on Linux, netstat -rn on macOS and
# anywhere without ip. Not ss -rn, which lists sockets, not routes.
if [[ "${WORKBENCH_OS:-}" != "Mac" ]] && command -v ip &>/dev/null; then
    if _shell_alias_free routeprint; then
        alias routeprint="ip route"
    fi
    if _shell_alias_free printrt; then
        alias printrt="ip route"
    fi
elif command -v netstat &>/dev/null; then
    if _shell_alias_free routeprint; then
        alias routeprint="netstat -rn"
    fi
    if _shell_alias_free printrt; then
        alias printrt="netstat -rn"
    fi
fi

# ── SSH agent ─────────────────────────────────────────────────────────────────
if _shell_alias_free sshclear; then
    alias sshclear="ssh-add -D"
fi

# ── Better cat/bat ────────────────────────────────────────────────────────────
if command -v batcat &>/dev/null; then
    if _shell_alias_free cat; then
        alias cat="batcat -p"
    fi
    if _shell_alias_free bat; then
        alias bat="batcat"
    fi
elif command -v bat &>/dev/null; then
    if _shell_alias_free cat; then
        alias cat="bat -p"
    fi
fi

# ── Better top ────────────────────────────────────────────────────────────────
if command -v btop &>/dev/null; then
    if _shell_alias_free top; then
        alias top="btop"
    fi
elif command -v htop &>/dev/null; then
    if _shell_alias_free top; then
        alias top="htop"
    fi
fi

# ── Python ────────────────────────────────────────────────────────────────────
# if-blocks, not `command -v … && alias`: listings find an alias only at
# the start of a line.
if command -v python3 &>/dev/null; then
    if _shell_alias_free python; then
        alias python="python3"
    fi
fi
if command -v pip3 &>/dev/null; then
    if _shell_alias_free pip; then
        alias pip="pip3"
    fi
fi

# ── acpi power ────────────────────────────────────────────────────────────────
if command -v acpi &>/dev/null; then
    if _shell_alias_free battery; then
        alias battery="acpi -bi"
    fi
    if _shell_alias_free power; then
        alias power="acpi -a"
    fi
fi

# ── Tmux ──────────────────────────────────────────────────────────────────────
if command -v tmux &>/dev/null; then
    if _shell_alias_free tmux-new; then
        alias tmux-new='tmux new-session -s main'
    fi
    if _shell_alias_free tmux-attach; then
        alias tmux-attach='tmux attach-session -t main'
    fi
    # Reload the config tmux reads: the first that exists in tmux's own
    # search order. Your file holds workbench's block (workbench-core D82),
    # so this reloads both. Defined with 'function': a shell that already
    # has 0.7.x's tmux-reload alias would expand it in 'tmux-reload()' and
    # fail to parse; neither bash nor zsh expands the name after 'function'.
    # The unalias then stops that old alias shadowing the function. D110: it
    # used to remove ANY alias of that name, a host's included; now only
    # 0.7.x's own text goes, and a host's alias or function of the name is
    # left in place, with no tmux-reload of ours defined over it.
    _shell_old_tmux_reload="$(alias tmux-reload 2>/dev/null)"
    # shellcheck disable=SC2016  # matching 0.7.x's alias text literally
    case "${_shell_old_tmux_reload}" in
        *'tmux source-file "${HOME}/.config/tmux/tmux.conf"'*) unalias tmux-reload 2>/dev/null || true ;;
    esac
    unset _shell_old_tmux_reload
    if _shell_alias_free tmux-reload; then
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
    if _shell_alias_free code; then
        alias code="code-insiders"
    fi
fi

# ── Clipboard (Wayland) ───────────────────────────────────────────────────────
if command -v wl-copy &>/dev/null; then
    if _shell_alias_free copy; then
        alias copy="wl-copy"
    fi
    if _shell_alias_free clip; then
        alias clip="wl-copy"
    fi
fi

# ── File manager ──────────────────────────────────────────────────────────────
if command -v nautilus &>/dev/null; then
    if _shell_alias_free explorer; then
        alias explorer="nautilus --browser &"
    fi
fi

# ── VPN ───────────────────────────────────────────────────────────────────────
if command -v nordvpn &>/dev/null; then
    if _shell_alias_free nordc; then
        alias nordc="nordvpn connect"
    fi
    if _shell_alias_free nordd; then
        alias nordd="nordvpn disconnect"
    fi
fi

# ── Fun ───────────────────────────────────────────────────────────────────────
if command -v cmatrix &>/dev/null; then
    if _shell_alias_free matrix; then
        alias matrix="cmatrix -abs"
    fi
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
    if _shell_alias_free aliases; then
        alias aliases="get-functions"
    fi
    if _shell_alias_free reset-shell; then
        alias reset-shell="clear && get-functions --no-pager --no-aliases"
    fi
    if _shell_alias_free rs; then
        alias rs="clear && get-functions --no-pager --no-aliases"
    fi
fi

# ── wb tools shortcut ─────────────────────────────────────────────────────────
if command -v wb &>/dev/null; then
    if _shell_alias_free installers; then
        alias installers="wb tools list"
    fi
fi

# ── SSH hosts ─────────────────────────────────────────────────────────────────
# If list-ssh-hosts is defined (workbench-ssh), use it; otherwise fall back to
# a simple grep.
if declare -f list-ssh-hosts &>/dev/null; then
    if _shell_alias_free sshhosts; then
        alias sshhosts="list-ssh-hosts"
    fi
else
    if _shell_alias_free sshhosts; then
        alias sshhosts='grep -E "^Host\s" "${HOME}/.ssh/config"'
    fi
fi

# ── iTerm2 ────────────────────────────────────────────────────────────────────
if command -v it2profile &>/dev/null; then
    if _shell_alias_free solarized; then
        alias solarized="it2profile -s Solarized"
    fi
    if _shell_alias_free black; then
        alias black="it2profile -s Black"
    fi
    if _shell_alias_free smooth; then
        alias smooth="it2profile -s Smooth"
    fi
fi

# ── Shell-specific ────────────────────────────────────────────────────────────
if _shell_in_zsh; then
    if _shell_alias_free zshconfig; then
        alias zshconfig='${VISUAL:-vim} "${HOME}/.zshrc"'
    fi
    if _shell_alias_free zshreload; then
        alias zshreload="exec zsh"
    fi
    if _shell_alias_free history; then
        alias history="history 1"
    fi
fi

if _shell_in_bash; then
    if _shell_alias_free bashconfig; then
        alias bashconfig='${VISUAL:-vim} "${HOME}/.bashrc"'
    fi
    if _shell_alias_free bashreload; then
        alias bashreload="exec bash"
    fi
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
