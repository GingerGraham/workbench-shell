#!/usr/bin/env bash
# shell/installers.sh — workbench-shell
# install-oh-my-posh, install-starship, install-oh-my-zsh, install-zsh,
# install-zsh-default-shell, install-zsh-plugins, install-direnv,
# install-fzf, install-neovim and their per-distro helpers. Ported from
# workbench-precursor's lazy/installers-prompt.sh and the direnv/fzf/neovim
# slice of lazy/installers-dev.sh (that file split five ways across Wave C
# modules, per the module map's own §7 call-out).
#
# WORKBENCH_OS/WORKBENCH_DISTRO/WORKBENCH_SHELL are workbench-core Core API
# facts (contracts/core-api.md), replacing the precursor's DOTFILES_OS/
# DOTFILES_DISTRO/DOTFILES_SHELL. _download_file_robust/_str_lower come from
# workbench-core's Core API (lib/core/installers-common.sh, lib/core/functions.sh).

# _gh_release_asset_url <api_response_json> <extended_regex_pattern>
# Extracts the first browser_download_url whose filename matches <pattern>.
# Small enough that it's duplicated per-module rather than promoted to Core
# API (same as workbench-git's copy) — see workbench-core ARCHITECTURE.md
# §12 D34 for the bar that's actually applied for promotion.
_gh_release_asset_url() {
    local api_response="$1" pattern="$2"
    printf '%s' "${api_response}" \
        | grep -Eo '"browser_download_url": *"[^"]+"' \
        | sed -E 's/.*"(https[^"]+)"/\1/' \
        | grep -E "${pattern}" \
        | head -1
}

# ── Oh-My-Posh install ────────────────────────────────────────────────────────

_omp-install-linux() {
    if command -v oh-my-posh &>/dev/null; then
        if oh-my-posh upgrade; then
            log_info "oh-my-posh updated successfully"
            return 0
        else
            log_error "oh-my-posh update failed. Check your installation or try updating manually."
            return 1
        fi
    fi

    if command -v curl &>/dev/null; then
        curl -s https://ohmyposh.dev/install.sh | bash
    elif command -v wget &>/dev/null; then
        wget -qO- https://ohmyposh.dev/install.sh | bash
    else
        log_error "curl or wget required to install oh-my-posh"
        return 1
    fi
}

_omp-install-macos() {
    if command -v oh-my-posh &>/dev/null && command -v brew &>/dev/null; then
        if brew update && brew upgrade oh-my-posh; then
            log_info "oh-my-posh updated successfully via Homebrew"
            return 0
        elif oh-my-posh upgrade; then
            log_info "oh-my-posh updated successfully via built-in updater"
            return 0
        else
            log_error "oh-my-posh update failed. Check your installation or try updating manually."
            return 1
        fi
    fi

    if command -v brew &>/dev/null; then
        brew install jandedobbeleer/oh-my-posh/oh-my-posh
    else
        _omp-install-linux
    fi
}

install-oh-my-posh() {
    case "${WORKBENCH_OS}" in
        Linux) _omp-install-linux ;;
        Mac)   _omp-install-macos ;;
        *)     log_error "Unsupported OS for oh-my-posh install"; return 1 ;;
    esac
}

installed-oh-my-posh() {
    command -v oh-my-posh &>/dev/null
}

# ── starship install/update ─────────────────────────────────────────────────

_starship-install-linux() {
    local install_dir="${HOME}/.local/bin"
    mkdir -p "${install_dir}"
    # The official script overwrites the binary in place, so this call
    # serves as both the initial install and subsequent updates.
    if curl -sS https://starship.rs/install.sh | sh -s -- -y -b "${install_dir}"; then
        log_info "starship installed/updated in ${install_dir}"
    else
        log_error "starship install/update failed. Check your installation or try updating manually."
        return 1
    fi
}

_starship-install-macos() {
    if command -v starship &>/dev/null; then
        brew upgrade starship
    else
        brew install starship
    fi
}

install-starship() {
    case "${WORKBENCH_OS}" in
        Linux) _starship-install-linux ;;
        Mac)   _starship-install-macos ;;
        *)     log_error "Unsupported OS for starship install"; return 1 ;;
    esac
}

installed-starship() {
    command -v starship &>/dev/null
}

# ── oh-my-zsh install ─────────────────────────────────────────────────────────

install-oh-my-zsh() {
    if command -v omz &>/dev/null; then
        if omz update; then
            log_info "oh-my-zsh updated successfully"
            return 0
        else
            log_error "oh-my-zsh update failed. Check your installation or try updating manually."
            return 1
        fi
    fi

    if command -v curl &>/dev/null; then
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    elif command -v wget &>/dev/null; then
        sh -c "$(wget https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh -O -)"
    elif command -v fetch &>/dev/null; then
        sh -c "$(fetch -o - https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    else
        log_error "curl or wget required to install oh-my-zsh"
        return 1
    fi
}

# Mirrors install-oh-my-zsh's own idempotency check — the omz CLI wrapper,
# not the ~/.oh-my-zsh directory, since that's what the installer itself
# already uses to decide "already installed" vs "fresh install".
installed-oh-my-zsh() {
    command -v omz &>/dev/null
}

# ── zsh install ───────────────────────────────────────────────────────────────

_zsh-install-dnf() {
    local elevation_cmd; elevation_cmd="$(get-elevation-command)" || return 1
    log_info "Installing zsh via dnf..."
    ${elevation_cmd} dnf install -y zsh
}

_zsh-install-apt() {
    local elevation_cmd; elevation_cmd="$(get-elevation-command)" || return 1
    log_info "Installing zsh via apt..."
    ${elevation_cmd} apt-get update && ${elevation_cmd} apt-get install -y zsh
}

_zsh-install-zypper() {
    local elevation_cmd; elevation_cmd="$(get-elevation-command)" || return 1
    log_info "Installing zsh via zypper..."
    ${elevation_cmd} zypper install -y zsh
}

_zsh-install-pacman() {
    local elevation_cmd; elevation_cmd="$(get-elevation-command)" || return 1
    log_info "Installing zsh via pacman..."
    ${elevation_cmd} pacman -S --noconfirm zsh
}

_zsh-install-brew() {
    log_info "Installing zsh via brew..."
    brew install zsh
}

install-zsh() {
    if command -v zsh &>/dev/null; then
        log_info "zsh is already installed ($(zsh --version))"
        return 0
    fi

    case "${WORKBENCH_DISTRO}" in
        rhel)   _zsh-install-dnf    ;;
        debian) _zsh-install-apt    ;;
        suse)   _zsh-install-zypper ;;
        arch)   _zsh-install-pacman ;;
        *)
            if [[ "${WORKBENCH_OS}" == "Mac" ]]; then
                _zsh-install-brew
            else
                log_error "install-zsh: unsupported distro '${WORKBENCH_DISTRO}' — install zsh manually"
                return 1
            fi
            ;;
    esac || return 1

    log_info "zsh installed. To set as your default shell, run: install-zsh-default-shell"
}

installed-zsh() {
    command -v zsh &>/dev/null
}

install-zsh-default-shell() {
    if ! command -v zsh &>/dev/null; then
        log_error "zsh is not installed — run install-zsh first"
        return 1
    fi

    local zsh_path; zsh_path="$(command -v zsh)"
    if [[ "${SHELL}" == "${zsh_path}" ]]; then
        log_info "zsh is already your default shell"
        return 0
    fi

    # Ensure zsh is in /etc/shells (required for chsh)
    if ! grep -qxF "${zsh_path}" /etc/shells 2>/dev/null; then
        log_info "Adding ${zsh_path} to /etc/shells..."
        local elevation_cmd; elevation_cmd="$(get-elevation-command)" || return 1
        echo "${zsh_path}" | ${elevation_cmd} tee -a /etc/shells >/dev/null
    fi

    log_info "Changing default shell to ${zsh_path}..."
    chsh -s "${zsh_path}"
    log_info "Default shell changed. Log out and back in (or start a new session) to apply."
}

# Not "is zsh installed" — install-zsh-default-shell is a system-config
# action (chsh), not a package install. Mirrors its own idempotency check:
# is zsh both present AND the account's current default shell.
installed-zsh-default-shell() {
    local zsh_path
    zsh_path="$(command -v zsh)" || return 1
    [[ "${SHELL}" == "${zsh_path}" ]]
}

# ── zsh plugin install ────────────────────────────────────────────────────────
# Installs zsh-autosuggestions and zsh-syntax-highlighting.
# Delivery method, in priority order:
#   1. Distro package manager    — system packages where available
#   2. Standalone git clone      — fallback to ~/.local/share/zsh/plugins/

_zsh-plugins-install-packages-dnf() {
    local elevation_cmd; elevation_cmd="$(get-elevation-command)" || return 1
    ${elevation_cmd} dnf install -y zsh-autosuggestions zsh-syntax-highlighting
}

_zsh-plugins-install-packages-apt() {
    local elevation_cmd; elevation_cmd="$(get-elevation-command)" || return 1
    ${elevation_cmd} apt-get update && \
        ${elevation_cmd} apt-get install -y zsh-autosuggestions zsh-syntax-highlighting
}

_zsh-plugins-install-packages-zypper() {
    local elevation_cmd; elevation_cmd="$(get-elevation-command)" || return 1
    ${elevation_cmd} zypper install -y zsh-autosuggestions zsh-syntax-highlighting
}

_zsh-plugins-install-packages-pacman() {
    local elevation_cmd; elevation_cmd="$(get-elevation-command)" || return 1
    ${elevation_cmd} pacman -S --noconfirm zsh-autosuggestions zsh-syntax-highlighting
}

_zsh-plugins-install-packages-brew() {
    brew install zsh-autosuggestions zsh-syntax-highlighting
}

_zsh-plugins-install-standalone() {
    local plugin_dir="${HOME}/.local/share/zsh/plugins"
    mkdir -p "${plugin_dir}"

    log_info "Installing zsh plugins to ${plugin_dir}..."

    if [[ ! -d "${plugin_dir}/zsh-autosuggestions" ]]; then
        if git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions \
            "${plugin_dir}/zsh-autosuggestions"; then
            log_info "zsh-autosuggestions cloned"
        else
            log_error "Failed to clone zsh-autosuggestions"
            return 1
        fi
    else
        log_info "zsh-autosuggestions already present"
    fi

    if [[ ! -d "${plugin_dir}/zsh-syntax-highlighting" ]]; then
        if git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting \
            "${plugin_dir}/zsh-syntax-highlighting"; then
            log_info "zsh-syntax-highlighting cloned"
        else
            log_error "Failed to clone zsh-syntax-highlighting"
            return 1
        fi
    else
        log_info "zsh-syntax-highlighting already present"
    fi

    log_info "Plugins installed. Reload your shell to activate."
}

install-zsh-plugins() {
    if [[ "${WORKBENCH_SHELL}" != "zsh" ]]; then
        log_error "install-zsh-plugins: must be run from zsh"
        return 1
    fi

    if ! command -v zsh &>/dev/null; then
        log_error "install-zsh-plugins: zsh not found — run install-zsh first"
        return 1
    fi

    local _pkg_installed=false
    case "${WORKBENCH_DISTRO}" in
        rhel)   _zsh-plugins-install-packages-dnf    && _pkg_installed=true ;;
        debian) _zsh-plugins-install-packages-apt    && _pkg_installed=true ;;
        suse)   _zsh-plugins-install-packages-zypper && _pkg_installed=true ;;
        arch)   _zsh-plugins-install-packages-pacman && _pkg_installed=true ;;
        *)
            if [[ "${WORKBENCH_OS}" == "Mac" ]]; then
                _zsh-plugins-install-packages-brew && _pkg_installed=true
            fi
            ;;
    esac

    if [[ "${_pkg_installed}" == "true" ]]; then
        log_info "Plugins installed via package manager. Reload your shell to activate."
        return 0
    fi

    log_info "Package manager install unavailable — falling back to git clone..."
    _zsh-plugins-install-standalone
}

# No installed-zsh-plugins predicate: install-zsh-plugins installs two
# plugins via whichever of five different delivery paths succeeds first
# (dnf/apt/zypper/pacman/brew package, or a standalone git clone to
# ~/.local/share/zsh/plugins/), each landing files at a different,
# distro-specific path, and unlike every other installer in this file it
# never verifies its own success — no existing check to mirror. A
# multi-path guess would be exactly the "not confident it's genuinely
# correct" case docs/module-authoring.md says to leave undeclared. Stays
# unresponsive to `wb tools upgrade`; fully installable via `wb tools
# install zsh-plugins`.

# ── direnv install ────────────────────────────────────────────────────────────

_direnv-install-rhel() {
    local elevation_cmd; elevation_cmd="$(get-elevation-command)" || return 1
    ${elevation_cmd} dnf install -y direnv
}

_direnv-install-debian() {
    local elevation_cmd; elevation_cmd="$(get-elevation-command)" || return 1
    ${elevation_cmd} apt-get update && ${elevation_cmd} apt-get install -y direnv
}

_direnv-install-suse() {
    local elevation_cmd; elevation_cmd="$(get-elevation-command)" || return 1
    ${elevation_cmd} zypper install -y direnv
}

_direnv-install-arch() {
    local elevation_cmd; elevation_cmd="$(get-elevation-command)" || return 1
    ${elevation_cmd} pacman -S --noconfirm direnv
}

_direnv-install-mac() {
    command -v brew &>/dev/null || { log_error "Homebrew required on macOS"; return 1; }
    if command -v direnv &>/dev/null; then brew upgrade direnv; else brew install direnv; fi
}

# Distro-independent fallback: official install script → ~/.local/bin
_direnv-install-script() {
    log_info "Falling back to the official direnv install script..."
    command -v curl &>/dev/null || { log_error "curl is required for the fallback install"; return 1; }
    mkdir -p "${HOME}/.local/bin"
    curl -sfL https://direnv.net/install.sh | bin_path="${HOME}/.local/bin" bash
    [[ ":${PATH}:" != *":${HOME}/.local/bin:"* ]] \
        && log_warn "${HOME}/.local/bin is not on PATH — add it in ~/.config/workbench/local/settings.sh"
}

install-direnv() {
    log_info "Installing or updating direnv..."

    case "${WORKBENCH_OS}" in
        Mac)
            _direnv-install-mac
            ;;
        Linux)
            local ok=1
            case "${WORKBENCH_DISTRO}" in
                rhel)   _direnv-install-rhel   && ok=0 ;;
                debian) _direnv-install-debian && ok=0 ;;
                suse)   _direnv-install-suse   && ok=0 ;;
                arch)   _direnv-install-arch   && ok=0 ;;
                *)      log_warn "Unknown distro (${WORKBENCH_DISTRO}) — using install script" ;;
            esac
            [[ "${ok}" -ne 0 ]] && { _direnv-install-script || return 1; }
            ;;
        *)
            log_error "Unsupported OS for direnv install"; return 1
            ;;
    esac

    if command -v direnv &>/dev/null; then
        log_info "direnv installed: $(direnv version 2>/dev/null)"

        # Attempt to install the shell hook into this session immediately —
        # this module's own shell/direnv.sh, resolved relative to this file
        # (both live in the same fetched snapshot — contracts/manifest-spec.md
        # D16: register.list points straight at <module>/current/<src>).
        local _installers_dir; _installers_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        local direnv_tool_file="${_installers_dir}/direnv.sh"
        if [[ -f "${direnv_tool_file}" ]]; then
            # shellcheck disable=SC1090
            source "${direnv_tool_file}"
        fi

        echo
        log_warn "If 'direnv allow' or .envrc loading doesn't work in this shell,"
        log_warn "open a new terminal / log out and back in to fully activate direnv."
        echo
        echo "  Allow a project's .envrc with:"
        echo "    direnv allow"
    else
        log_warn "direnv not found in PATH after install. Restart your shell or check ~/.local/bin."
    fi
}

installed-direnv() {
    command -v direnv &>/dev/null
}

# ── fzf install ───────────────────────────────────────────────────────────────

_fzf-install-rhel() {
    local elevation_cmd; elevation_cmd="$(get-elevation-command)" || return 1
    if command -v dnf &>/dev/null; then
        # fzf is in EPEL on RHEL 8, base repos on RHEL 9+ and Fedora
        ${elevation_cmd} dnf install -y fzf
    elif command -v yum &>/dev/null; then
        ${elevation_cmd} yum install -y epel-release 2>/dev/null || true
        ${elevation_cmd} yum install -y fzf
    else
        log_error "Neither dnf nor yum found"; return 1
    fi
}

_fzf-install-debian() {
    local elevation_cmd; elevation_cmd="$(get-elevation-command)" || return 1
    ${elevation_cmd} apt-get update
    ${elevation_cmd} apt-get install -y fzf
}

_fzf-install-suse() {
    local elevation_cmd; elevation_cmd="$(get-elevation-command)" || return 1
    ${elevation_cmd} zypper install -y fzf
}

_fzf-install-arch() {
    local elevation_cmd; elevation_cmd="$(get-elevation-command)" || return 1
    ${elevation_cmd} pacman -S --noconfirm fzf
}

_fzf-install-mac() {
    command -v brew &>/dev/null || { log_error "brew is required on macOS"; return 1; }
    if command -v fzf &>/dev/null; then brew upgrade fzf; else brew install fzf; fi
}

# Binary fallback — latest GitHub release → ~/.local/bin
_fzf-install-binary() {
    log_info "fzf: falling back to binary install from GitHub releases..."
    command -v curl &>/dev/null || { log_error "curl is required"; return 1; }
    command -v tar  &>/dev/null || { log_error "tar is required";  return 1; }

    local api_response ver arch url asset tmp_dir
    api_response="$(curl -s https://api.github.com/repos/junegunn/fzf/releases/latest)"
    ver="$(printf '%s' "${api_response}" | grep '"tag_name":' \
        | sed -E 's/.*"tag_name": *"v?([^"]+)".*/\1/' | head -1)"
    [[ -z "${ver}" ]] && { log_error "fzf: could not determine latest version"; return 1; }

    case "${WORKBENCH_ARCH}" in
        x86_64)        arch="amd64" ;;
        aarch64|arm64) arch="arm64" ;;
        *) log_error "fzf: unsupported architecture ${WORKBENCH_ARCH}"; return 1 ;;
    esac

    asset="fzf-${ver}-linux_${arch}.tar.gz"
    url="$(_gh_release_asset_url "${api_response}" "fzf-${ver}-linux_${arch}\.tar\.gz")"
    [[ -z "${url}" ]] && { log_error "fzf: no matching asset for ${asset}"; return 1; }

    tmp_dir="$(mktemp -d)"
    _download_file_robust "${url}" "${tmp_dir}/${asset}" || { rm -rf "${tmp_dir}"; return 1; }
    tar -xzf "${tmp_dir}/${asset}" -C "${tmp_dir}"
    mkdir -p "${HOME}/.local/bin"
    install -m 755 "${tmp_dir}/fzf" "${HOME}/.local/bin/fzf"
    rm -rf "${tmp_dir}"
    log_info "fzf ${ver} installed to ~/.local/bin/fzf"
}

install-fzf() {
    log_info "Installing or updating fzf..."

    case "${WORKBENCH_OS}" in
        Mac) _fzf-install-mac; return $? ;;
        Linux) ;;
        *) log_error "Unsupported OS for fzf install"; return 1 ;;
    esac

    local ok=1
    case "${WORKBENCH_DISTRO}" in
        rhel)   _fzf-install-rhel   && ok=0 ;;
        debian) _fzf-install-debian && ok=0 ;;
        suse)   _fzf-install-suse   && ok=0 ;;
        arch)   _fzf-install-arch   && ok=0 ;;
        *)      log_warn "fzf: unknown distro (${WORKBENCH_DISTRO}) — trying binary install" ;;
    esac
    [[ "${ok}" -ne 0 ]] && { _fzf-install-binary || return 1; }

    if command -v fzf &>/dev/null; then
        log_info "fzf installed: $(fzf --version)"
    else
        log_warn "fzf not on PATH after install — check ~/.local/bin is in PATH"
    fi
}

installed-fzf() {
    command -v fzf &>/dev/null
}

# ── Neovim install ────────────────────────────────────────────────────────────
#
# Always installs from upstream GitHub release tarballs, on every platform —
# including macOS (no Homebrew path). This is deliberate: distro packages lag
# badly on Debian/Ubuntu, and a single install path across every platform is
# far easier to reason about than a version-floor matrix with per-distro
# sticky method tracking.
#
# Config is not this function's concern — workbench-shell doesn't ship a
# neovim config; use your own separately-tracked nvim-config repo if you
# have one.

# _neovim_latest_tag <api_response_json>
# Extracts the release tag from an already-fetched API response (reusing the
# response install-neovim also needs for asset resolution, rather than a
# second API call). On failure (rate limit, network) logs and returns non-zero
# instead of guessing a version.
_neovim_latest_tag() {
    local api_response="$1" tag
    tag="$(printf '%s' "${api_response}" | grep '"tag_name":' \
        | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/' | head -1)"
    if [[ -z "${tag}" ]]; then
        log_error "neovim: could not determine latest version (GitHub API rate limit?)"
        return 1
    fi
    printf '%s' "${tag}"
}

# _neovim_asset_name — maps uname -s / uname -m to the release asset filename.
# Returns non-zero on an unsupported platform so callers bail early.
_neovim_asset_name() {
    local kernel machine
    kernel="$(uname -s)"
    machine="$(uname -m)"
    case "${kernel}" in
        Linux)
            case "${machine}" in
                x86_64)        printf 'nvim-linux-x86_64.tar.gz' ;;
                aarch64|arm64) printf 'nvim-linux-arm64.tar.gz' ;;
                *) log_error "neovim: unsupported architecture: ${machine}"; return 1 ;;
            esac
            ;;
        Darwin)
            case "${machine}" in
                x86_64) printf 'nvim-macos-x86_64.tar.gz' ;;
                arm64)  printf 'nvim-macos-arm64.tar.gz' ;;
                *) log_error "neovim: unsupported architecture: ${machine}"; return 1 ;;
            esac
            ;;
        *) log_error "neovim: unsupported platform: ${kernel}"; return 1 ;;
    esac
}

# Cleanup case 1: a real file (not a symlink) already at ~/.local/bin/nvim —
# a stale wrapper script from a previous manual/other install. Backed up
# either way, not silently overwritten.
_neovim_cleanup_wrapper_script() {
    local nvim_bin="${HOME}/.local/bin/nvim"
    [[ -e "${nvim_bin}" && ! -L "${nvim_bin}" ]] || return 0

    log_info "Found an existing non-symlink file at ${nvim_bin}"
    local backup="${nvim_bin}.pre-workbench.bak"
    mv "${nvim_bin}" "${backup}"
    log_info "Backed up to ${backup}"
}

# Cleanup case 2: a stale ~/.local/share/nvim/nvim.appimage from a previous
# AppImage-based install.
#
# ~/.local/share/nvim is Neovim's XDG *DATA* directory — it holds the
# plugin tree and site files. REMOVE THE FILE ONLY. Removing the DIRECTORY
# would destroy the plugin install. This is the single most dangerous line
# in this file.
_neovim_cleanup_appimage_file() {
    local appimage="${HOME}/.local/share/nvim/nvim.appimage"
    [[ -f "${appimage}" ]] || return 0
    log_info "Removing stale appimage file: ${appimage} (leaving the rest of ~/.local/share/nvim untouched)"
    rm -f "${appimage}"
}

# Cleanup case 3: a package-manager-managed Neovim. Detected via the package
# database, not `command -v` — `command -v` would also match our own tarball
# install once it's on PATH. ~/.local/bin is prepended to PATH ahead of any
# distro package, so the tarball binary wins regardless of whether the
# packaged copy is removed — removal here is hygiene, not necessity. Never
# removed without an explicit yes.
_neovim_cleanup_package_install() {
    local packaged=""
    if [[ "${WORKBENCH_OS}" == "Mac" ]]; then
        command -v brew &>/dev/null && brew list --versions neovim &>/dev/null \
            && packaged="$(brew list --versions neovim 2>/dev/null)"
    else
        case "${WORKBENCH_DISTRO}" in
            rhel|suse)
                command -v rpm &>/dev/null && rpm -q neovim &>/dev/null \
                    && packaged="$(rpm -q neovim 2>/dev/null)"
                ;;
            debian)
                command -v dpkg &>/dev/null && dpkg -s neovim &>/dev/null \
                    && packaged="$(dpkg -s neovim 2>/dev/null | awk -F': ' '/^Version:/{print $2}')"
                ;;
            arch)
                command -v pacman &>/dev/null && pacman -Q neovim &>/dev/null \
                    && packaged="$(pacman -Q neovim 2>/dev/null)"
                ;;
        esac
    fi
    [[ -z "${packaged}" ]] && return 0

    log_warn "A package-manager-installed Neovim was found: ${packaged}"
    # shellcheck disable=SC2088
    log_warn "~/.local/bin is ahead of it on PATH, so the tarball install takes precedence regardless."

    if [[ ! -e /dev/tty ]]; then
        log_warn "Non-interactive shell — leaving the packaged Neovim in place."
        return 0
    fi

    local reply
    _read_prompt "Remove the package-manager Neovim too? [y/N]: " reply
    case "$(_str_lower "${reply}")" in
        y|yes) ;;
        *) log_info "Keeping the package-manager Neovim installed."; return 0 ;;
    esac

    local elevation_cmd
    elevation_cmd="$(get-elevation-command)" || { log_warn "No elevation available — cannot remove the packaged Neovim."; return 0; }

    if [[ "${WORKBENCH_OS}" == "Mac" ]]; then
        brew uninstall neovim
    else
        case "${WORKBENCH_DISTRO}" in
            rhel|suse) ${elevation_cmd} rpm -e neovim ;;
            debian)    ${elevation_cmd} dpkg -r neovim ;;
            arch)      ${elevation_cmd} pacman -Rs --noconfirm neovim ;;
            *) log_warn "Unknown distro — remove the packaged Neovim manually if desired." ;;
        esac
    fi
}

# Prune every ~/.local/opt/nvim-* directory except the one just installed.
_neovim_prune_old_installs() {
    local keep_dir="$1" d
    if [[ -n "${ZSH_VERSION}" ]]; then setopt nullglob; else shopt -s nullglob; fi
    for d in "${HOME}/.local/opt"/nvim-*; do
        [[ -d "${d}" && "${d}" != "${keep_dir}" ]] && rm -rf "${d}"
    done
    if [[ -n "${ZSH_VERSION}" ]]; then unsetopt nullglob; else shopt -u nullglob; fi
}

install-neovim() {
    log_info "Installing or updating Neovim..."
    command -v curl &>/dev/null || { log_error "curl is required"; return 1; }
    command -v tar  &>/dev/null || { log_error "tar is required";  return 1; }

    local api_response tag
    api_response="$(curl -fsSL https://api.github.com/repos/neovim/neovim/releases/latest 2>/dev/null)"
    tag="$(_neovim_latest_tag "${api_response}")" || return 1

    local install_dir="${HOME}/.local/opt/nvim-${tag}"
    local nvim_bin="${HOME}/.local/bin/nvim"

    if [[ -L "${nvim_bin}" && "$(readlink "${nvim_bin}")" == "${install_dir}/bin/nvim" ]]; then
        log_info "Neovim ${tag} is already installed and symlinked — skipping"
        return 0
    fi

    local asset; asset="$(_neovim_asset_name)" || return 1
    local asset_pattern; asset_pattern="$(printf '%s' "${asset}" | sed 's/\./\\./g')"
    local download_url
    download_url="$(_gh_release_asset_url "${api_response}" "${asset_pattern}\$")"
    if [[ -z "${download_url}" ]]; then
        log_error "neovim: no release asset matching ${asset} in ${tag}"
        return 1
    fi

    _neovim_cleanup_wrapper_script
    _neovim_cleanup_appimage_file
    _neovim_cleanup_package_install

    local tmp_dir; tmp_dir="$(mktemp -d)"
    log_info "Downloading ${asset}..."
    if ! _download_file_robust "${download_url}" "${tmp_dir}/${asset}"; then
        rm -rf "${tmp_dir}"; return 1
    fi

    log_info "Extracting to ${install_dir}..."
    mkdir -p "${HOME}/.local/opt"
    rm -rf "${install_dir}"
    mkdir -p "${install_dir}"
    if ! tar -xzf "${tmp_dir}/${asset}" -C "${install_dir}" --strip-components=1; then
        log_error "neovim: extraction failed"
        rm -rf "${tmp_dir}" "${install_dir}"
        return 1
    fi
    rm -rf "${tmp_dir}"

    if [[ "${WORKBENCH_OS}" == "Mac" ]] && command -v xattr &>/dev/null; then
        # Without this, Gatekeeper blocks the binary — the tarball isn't notarized.
        xattr -cr "${install_dir}"
    fi

    mkdir -p "${HOME}/.local/bin"
    ln -sf "${install_dir}/bin/nvim" "${nvim_bin}"

    _neovim_prune_old_installs "${install_dir}"

    if command -v nvim &>/dev/null; then
        log_info "Neovim installed: $(nvim --version 2>/dev/null | head -1)"
    else
        log_warn "nvim not found on PATH after install. Restart your shell or check ~/.local/bin."
    fi
}

# neovim's binary is nvim, not neovim — install-neovim's own final check
# uses the same name.
installed-neovim() {
    command -v nvim &>/dev/null
}
