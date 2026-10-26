#!/usr/bin/env bash
# tests/check-shell-fixes.sh — workbench-shell
# The 2026-10 pre-launch fixes, each checked in the shell it applies to:
#   - routeprint/printrt show routes (ip route, else netstat -rn), not ss;
#   - get-python-versions works in zsh (no nomatch glob);
#   - fzf's integration is eval'd (source <(…) is a no-op on bash 3.2);
#   - zsh-plugins.sh finds plugins where the module's own installer puts
#     them, sourcing syntax highlighting last; installed-zsh-plugins
#     checks the same paths, in bash;
#   - install-zsh-plugins runs under wb tools (bash);
#   - install-direnv doesn't source direnv.sh into the wb tools process;
#   - oh-my-posh finds Homebrew's theme directory, and a missing one isn't
#     a warning on every start.
# Stubs stand in for the tools and the Core API. No network.
# Plain bash, numbered OK:/FAIL: checks, no framework. zsh checks SKIP:
# only when zsh isn't installed.
#
# SC2015: '[[ cond ]] && ok || fail' is this suite's assertion idiom.
# SC2016: the single-quoted snippets are expanded by the shell they run in.
# shellcheck disable=SC2015,SC2016
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

FAILED=0
check_no=0
ok()   { check_no=$((check_no + 1)); echo "OK:   [$check_no] $*"; }
fail() { check_no=$((check_no + 1)); echo "FAIL: [$check_no] $*"; FAILED=$((FAILED + 1)); }

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
mkdir -p "${WORK}/home" "${WORK}/bin-ip" "${WORK}/bin-netstat" "${WORK}/bin-fzf"
for t in bin-ip/ip bin-netstat/netstat; do
    printf '#!/bin/sh\nexit 0\n' > "${WORK}/${t}"
    chmod +x "${WORK}/${t}"
done
printf '#!/bin/sh\necho "FZF_INTEGRATION=$1"\n' > "${WORK}/bin-fzf/fzf"
chmod +x "${WORK}/bin-fzf/fzf"

STUBS='
log_info()  { :; }
log_warn()  { echo "WARN: $*" >&2; }
log_error() { echo "ERROR: $*" >&2; }
log_debug() { :; }
_wb_alias_availability()   { :; }
_wb_declare_availability() { :; }
_wb_availability_needs()   { :; }
'

# in_sh <shell> <PATH prefix> <commands>
in_sh() {
    HOME="${WORK}/home" PATH="$2:/usr/bin:/bin" "$1" -c "${STUBS}
        $3" 2>"${WORK}/err"
}

# ── routeprint / printrt ────────────────────────────────────────────────────
# /usr/bin and /bin come after the stub dir: only check the stub's choice
# when the host doesn't have the other tool there too.
out="$(in_sh bash "${WORK}/bin-ip" "WORKBENCH_OS=Linux; source '${REPO_ROOT}/shell/aliases.sh'; alias routeprint; alias printrt")"
[[ "${out}" == *"routeprint='ip route'"* && "${out}" == *"printrt='ip route'"* ]] \
    && ok "Linux with ip: routeprint/printrt are 'ip route'" \
    || fail "Linux with ip: ${out}"
if [[ ! -x /usr/bin/ip && ! -x /bin/ip ]]; then
    out="$(in_sh bash "${WORK}/bin-netstat" "WORKBENCH_OS=Linux; source '${REPO_ROOT}/shell/aliases.sh'; alias routeprint")"
    [[ "${out}" == *"routeprint='netstat -rn'"* ]] \
        && ok "without ip: routeprint is 'netstat -rn'" \
        || fail "without ip: ${out}"
else
    ok "(ip is installed in /usr/bin or /bin — without-ip case skipped)"
fi
out="$(in_sh bash "${WORK}/bin-ip:${WORK}/bin-netstat" "WORKBENCH_OS=Mac; source '${REPO_ROOT}/shell/aliases.sh'; alias routeprint")"
[[ "${out}" == *"routeprint='netstat -rn'"* ]] \
    && ok "macOS: routeprint is 'netstat -rn' even with an ip on PATH" \
    || fail "macOS: ${out}"
grep -vE '^[[:space:]]*#' "${REPO_ROOT}/shell/aliases.sh" | grep -q 'ss -rn' \
    && fail "aliases.sh still uses 'ss -rn' (sockets, not routes)" \
    || ok "no 'ss -rn' left in aliases.sh"

# ── get-python-versions ─────────────────────────────────────────────────────
expected="$(find /usr/bin /usr/local/bin -maxdepth 1 -type f -name 'python3*' ! -name '*-config' 2>/dev/null | sort | wc -l | tr -d ' ')"
for sh in bash zsh; do
    command -v "${sh}" &>/dev/null || { echo "SKIP: ${sh} not installed"; continue; }
    out="$(in_sh "${sh}" "" "source '${REPO_ROOT}/shell/aliases.sh'; get-python-versions; echo rc=\$?")"
    lines="$(printf '%s\n' "${out}" | grep -c ': ')"
    [[ "${out}" == *"rc=0"* && ! -s "${WORK}/err" && "${lines}" -eq "${expected}" ]] \
        && ok "${sh}: get-python-versions lists ${expected} interpreter(s), nothing on stderr" \
        || fail "${sh}: get-python-versions: ${out} / stderr: $(cat "${WORK}/err")"
done

# ── fzf integration ─────────────────────────────────────────────────────────
for sh in bash zsh; do
    command -v "${sh}" &>/dev/null || { echo "SKIP: ${sh} not installed"; continue; }
    out="$(in_sh "${sh}" "${WORK}/bin-fzf" "WORKBENCH_SHELL=${sh}; source '${REPO_ROOT}/shell/fzf.sh'; echo \"got=\${FZF_INTEGRATION:-}\"")"
    [[ "${out}" == "got=--${sh}" ]] \
        && ok "${sh}: fzf --${sh} output is evaluated" \
        || fail "${sh}: fzf integration: ${out}"
done
grep -qE '^[^#]*source <\(' "${REPO_ROOT}/shell/fzf.sh" \
    && fail "fzf.sh still uses source <(…) (a no-op on bash 3.2)" \
    || ok "fzf.sh has no source <(…)"

# ── zsh plugins ─────────────────────────────────────────────────────────────
# A fake plugin records its name when sourced.
fake_plugin() { # <path>
    mkdir -p "$(dirname "$1")"
    printf 'print -r -- "loaded $(basename "%s" .zsh)" >> "${HOME}/plugins.log"\n' "$1" > "$1"
}
xdg_plugins="${WORK}/home/.local/share/zsh/plugins"
fake_plugin "${xdg_plugins}/zsh-autosuggestions/zsh-autosuggestions.zsh"

out="$(in_sh bash "" "source '${REPO_ROOT}/shell/installers.sh'; installed-zsh-plugins && echo yes || echo no")"
[[ "${out}" == "no" ]] \
    && ok "bash: installed-zsh-plugins is false with only one plugin" \
    || fail "installed-zsh-plugins with one plugin: ${out}"

fake_plugin "${WORK}/home/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
out="$(in_sh bash "" "source '${REPO_ROOT}/shell/installers.sh'; installed-zsh-plugins && echo yes || echo no")"
[[ "${out}" == "yes" ]] \
    && ok "bash: installed-zsh-plugins is true with both (XDG data dir and ~/.zsh)" \
    || fail "installed-zsh-plugins with both: ${out}"

if command -v zsh &>/dev/null; then
    rm -f "${WORK}/home/plugins.log"
    in_sh zsh "" "source '${REPO_ROOT}/shell/zsh-plugins.sh'" >/dev/null
    [[ "$(cat "${WORK}/home/plugins.log" 2>/dev/null)" == "loaded zsh-autosuggestions"$'\n'"loaded zsh-syntax-highlighting" ]] \
        && ok "zsh: both plugins load from the same paths, syntax highlighting last" \
        || fail "zsh plugins loaded: $(cat "${WORK}/home/plugins.log" 2>/dev/null) / stderr: $(cat "${WORK}/err")"
    [[ ! -s "${WORK}/err" ]] \
        && ok "zsh: nothing on stderr" \
        || fail "zsh-plugins.sh stderr: $(cat "${WORK}/err")"
else
    echo "SKIP: zsh not installed — zsh-plugins.sh checks skipped"
fi
diff <(sed -n '/^_zsh_plugin_path() {/,/^}/p' "${REPO_ROOT}/shell/zsh-plugins.sh") \
     <(sed -n '/^_zsh_plugin_path() {/,/^}/p' "${REPO_ROOT}/shell/installers.sh") >/dev/null \
    && ok "_zsh_plugin_path is identical in zsh-plugins.sh and installers.sh" \
    || fail "_zsh_plugin_path differs between zsh-plugins.sh and installers.sh"

# ── install-zsh-plugins under wb tools (bash) ───────────────────────────────
mkdir -p "${WORK}/bin-pkg"
printf '#!/bin/sh\necho "dnf $*" >> "${HOME}/pkg.log"\n' > "${WORK}/bin-pkg/dnf"
printf '#!/bin/sh\nexit 0\n' > "${WORK}/bin-pkg/zsh"
chmod +x "${WORK}/bin-pkg/dnf" "${WORK}/bin-pkg/zsh"
out="$(in_sh bash "${WORK}/bin-pkg" "get-elevation-command() { printf ''; }
    WORKBENCH_SHELL=bash WORKBENCH_OS=Linux WORKBENCH_DISTRO=rhel
    source '${REPO_ROOT}/shell/installers.sh'; install-zsh-plugins; echo rc=\$?")"
[[ "${out}" == *"rc=0"* ]] && grep -q 'dnf install -y zsh-autosuggestions zsh-syntax-highlighting' "${WORK}/home/pkg.log" \
    && ok "install-zsh-plugins runs with WORKBENCH_SHELL=bash" \
    || fail "install-zsh-plugins in bash: ${out} / $(cat "${WORK}/err")"

# ── install-direnv ──────────────────────────────────────────────────────────
printf '#!/bin/sh\necho "dnf $*" >> "${HOME}/pkg.log"\n' > "${WORK}/bin-pkg/dnf"
printf '#!/bin/sh\n[ "$1" = version ] && echo 2.0.0\nexit 0\n' > "${WORK}/bin-pkg/direnv"
chmod +x "${WORK}/bin-pkg/direnv"
out="$(in_sh bash "${WORK}/bin-pkg" "get-elevation-command() { printf ''; }
    _wb_prompt_hook_registered() { return 1; }
    unset DIRENV_LOG_FORMAT
    WORKBENCH_SHELL=bash WORKBENCH_OS=Linux WORKBENCH_DISTRO=rhel
    source '${REPO_ROOT}/shell/installers.sh'; install-direnv >/dev/null; echo rc=\$? set=\${DIRENV_LOG_FORMAT+yes}")"
[[ "${out}" == "rc=0 set=" ]] \
    && ok "install-direnv doesn't source direnv.sh into the wb tools process" \
    || fail "install-direnv: ${out}"

# ── oh-my-posh theme directory ──────────────────────────────────────────────
mkdir -p "${WORK}/bin-omp" "${WORK}/brew/opt/oh-my-posh/themes"
printf '#!/bin/sh\nexit 0\n' > "${WORK}/bin-omp/oh-my-posh"
chmod +x "${WORK}/bin-omp/oh-my-posh"
out="$(in_sh bash "${WORK}/bin-omp" "HOMEBREW_PREFIX='${WORK}/brew' WORKBENCH_SHELL=bash
    source '${REPO_ROOT}/shell/omp.sh'; echo \"dir=\${OMP_THEME_DIR}\"")"
[[ "${out}" == "dir=${WORK}/brew/opt/oh-my-posh/themes" ]] \
    && ok "oh-my-posh: Homebrew's theme directory is found" \
    || fail "oh-my-posh theme dir: ${out}"
rm -rf "${WORK}/brew"
out="$(in_sh bash "${WORK}/bin-omp" "HOMEBREW_PREFIX='${WORK}/brew' WORKBENCH_SHELL=bash
    source '${REPO_ROOT}/shell/omp.sh'; echo \"dir=\${OMP_THEME_DIR}\"")"
if [[ -d /usr/local/opt/oh-my-posh/themes ]]; then
    ok "(/usr/local/opt/oh-my-posh/themes exists on this host — missing-directory case skipped)"
else
    [[ "${out}" == "dir=" && ! -s "${WORK}/err" ]] \
        && ok "oh-my-posh: no theme directory is not a warning" \
        || fail "oh-my-posh without themes: ${out} / stderr: $(cat "${WORK}/err")"
fi

echo
echo "==============================="
echo "Total OK/FAIL checks: ${check_no}, failed: ${FAILED}"
echo "==============================="
[[ "${FAILED}" -eq 0 ]]
