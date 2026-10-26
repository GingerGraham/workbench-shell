#!/usr/bin/env bash
# tests/check-installers-verified.sh — workbench-shell
# install-neovim and fzf's binary fallback (shell/installers.sh) check the
# release tarball against the SHA-256 GitHub publishes for it before
# unpacking anything: a missing digest refuses before downloading, a wrong
# one refuses before extracting, and the right one installs.
#
# Stubs the Core API surface rather than needing a workbench-core checkout
# (module CI's structural job runs tests/check-*.sh from this checkout
# alone): curl returns a canned releases-API response, _download_file_robust
# copies a local fixture tarball, and _wb_fetch_verified does what core's
# does — download, compare SHA-256, move into place only on a match. Core's
# own tests/check-fetch-verified.sh covers the real helper; this suite
# checks that the installers wire into it and stop when it refuses.
# _wb_gh_asset_digest and _wb_gh_release_asset_url are copied from core's
# lib/core/installers-common.sh so the canned JSON is parsed for real.
# Plain bash, numbered OK:/FAIL: checks, no framework. No network.
#
# SC2015: '[[ cond ]] && ok || fail' is this suite's assertion idiom.
# SC2317: stubs are called by the sourced installers, not directly.
# shellcheck disable=SC2015,SC2317
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

FAILED=0
check_no=0
ok()   { check_no=$((check_no + 1)); echo "OK:   [$check_no] $*"; }
fail() { check_no=$((check_no + 1)); echo "FAIL: [$check_no] $*"; FAILED=$((FAILED + 1)); }

if command -v sha256sum &>/dev/null; then
    sha256_of() { sha256sum "$1" | awk '{print $1}'; }
elif command -v shasum &>/dev/null; then
    sha256_of() { shasum -a 256 "$1" | awk '{print $1}'; }
else
    echo "SKIP: neither sha256sum nor shasum is installed"
    exit 0
fi

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
export HOME="${WORK}/home"
mkdir -p "${HOME}"
CALL_LOG="${WORK}/calls"

# ── Stubs standing in for workbench-core's Core API ─────────────────────────
log_info()  { :; }
log_warn()  { :; }
log_error() { :; }
log_debug() { :; }
get-elevation-command() { return 1; }

_wb_gh_release_asset_url() {
    local api_response="$1" pattern="$2"
    printf '%s' "${api_response}" \
        | grep -Eo '"browser_download_url": *"[^"]+"' \
        | sed -E 's/.*"(https[^"]+)"/\1/' \
        | grep -E "${pattern}" \
        | head -1
}
_wb_gh_asset_digest() {
    local api_json="$1" asset_url="$2"
    printf '%s' "${api_json}" \
        | grep -oE '"(digest|browser_download_url)"[[:space:]]*:[[:space:]]*("[^"]*"|null)' \
        | sed -E 's/^"(digest|browser_download_url)"[[:space:]]*:[[:space:]]*"?([^"]*)"?$/\1 \2/' \
        | awk -v want="${asset_url}" '
            $1 == "digest" { last_digest = $2; next }
            $1 == "browser_download_url" {
                if ($2 == want) { print last_digest; exit }
                last_digest = ""
            }
          ' \
        | sed -n 's/^sha256://p'
}
# FIXTURE is the local file every "download" copies.
_download_file_robust() { printf 'download %s\n' "$1" >> "${CALL_LOG}"; cp "${FIXTURE}" "$2"; }
_wb_fetch_verified() {
    printf 'fetch_verified %s %s\n' "$1" "$3" >> "${CALL_LOG}"
    local tmp="${WORK}/fetch.tmp"
    _download_file_robust "$1" "${tmp}" || return 1
    if [[ "$(sha256_of "${tmp}")" != "$3" ]]; then
        rm -f "${tmp}"
        return 1
    fi
    mv -f "${tmp}" "$2"
}
# API_JSON is what the releases API "returns".
curl() { printf '%s' "${API_JSON}"; }

# shellcheck source=shell/installers.sh
source "${REPO_ROOT}/shell/installers.sh"

WORKBENCH_OS="Linux"
WORKBENCH_DISTRO="none"
WORKBENCH_ARCH="x86_64"
wrong_sha="$(printf '%064d' 0)"

api_json() { # <tag> <asset-url> <digest-json-value>
    printf '{"tag_name":"%s","assets":[{"name":"x","digest":%s,"browser_download_url":"%s"}]}' "$1" "$3" "$2"
}

# ── Neovim ───────────────────────────────────────────────────────────────────
if nvim_asset="$(_neovim_asset_name 2>/dev/null)"; then
    mkdir -p "${WORK}/nvim-src/nvim-root/bin"
    printf '#!/bin/sh\necho NVIM v0.0.0-test\n' > "${WORK}/nvim-src/nvim-root/bin/nvim"
    chmod +x "${WORK}/nvim-src/nvim-root/bin/nvim"
    tar -czf "${WORK}/${nvim_asset}" -C "${WORK}/nvim-src" nvim-root
    FIXTURE="${WORK}/${nvim_asset}"
    nvim_url="https://example.invalid/neovim/${nvim_asset}"
    nvim_sha="$(sha256_of "${FIXTURE}")"

    # 1–2. No published digest: refused before anything is downloaded.
    : > "${CALL_LOG}"
    API_JSON="$(api_json v0.0.1 "${nvim_url}" null)"
    install-neovim >/dev/null 2>&1 \
        && fail "neovim, no digest: install succeeded" \
        || ok "neovim, no digest: refused"
    [[ ! -s "${CALL_LOG}" && ! -e "${HOME}/.local/opt/nvim-v0.0.1" ]] \
        && ok "neovim, no digest: nothing downloaded or extracted" \
        || fail "neovim, no digest: calls: $(cat "${CALL_LOG}")"

    # 3–4. Wrong digest: refused, nothing extracted or linked.
    : > "${CALL_LOG}"
    API_JSON="$(api_json v0.0.1 "${nvim_url}" "\"sha256:${wrong_sha}\"")"
    install-neovim >/dev/null 2>&1 \
        && fail "neovim, wrong digest: install succeeded" \
        || ok "neovim, wrong digest: refused"
    [[ ! -e "${HOME}/.local/opt/nvim-v0.0.1" && ! -L "${HOME}/.local/bin/nvim" ]] \
        && grep -q "^fetch_verified ${nvim_url} ${wrong_sha}$" "${CALL_LOG}" \
        && ok "neovim, wrong digest: verified through _wb_fetch_verified, nothing extracted or linked" \
        || fail "neovim, wrong digest: calls: $(cat "${CALL_LOG}"); opt: $(ls "${HOME}/.local/opt" 2>/dev/null)"

    # 5. Right digest: installed and linked.
    : > "${CALL_LOG}"
    API_JSON="$(api_json v0.0.1 "${nvim_url}" "\"sha256:${nvim_sha}\"")"
    install-neovim >/dev/null 2>&1
    [[ "$(readlink "${HOME}/.local/bin/nvim" 2>/dev/null)" == "${HOME}/.local/opt/nvim-v0.0.1/bin/nvim" ]] \
        && grep -q "^fetch_verified ${nvim_url} ${nvim_sha}$" "${CALL_LOG}" \
        && ok "neovim, matching digest: verified, extracted and linked" \
        || fail "neovim, matching digest: calls: $(cat "${CALL_LOG}"); link: $(readlink "${HOME}/.local/bin/nvim" 2>/dev/null)"
else
    echo "SKIP: neovim has no release asset for $(uname -s)/$(uname -m) — neovim checks skipped"
fi

# ── fzf binary fallback ──────────────────────────────────────────────────────
mkdir -p "${WORK}/fzf-src"
printf '#!/bin/sh\necho 0.0.1\n' > "${WORK}/fzf-src/fzf"
chmod +x "${WORK}/fzf-src/fzf"
fzf_asset="fzf-0.0.1-linux_amd64.tar.gz"
tar -czf "${WORK}/${fzf_asset}" -C "${WORK}/fzf-src" fzf
FIXTURE="${WORK}/${fzf_asset}"
fzf_url="https://example.invalid/fzf/${fzf_asset}"
fzf_sha="$(sha256_of "${FIXTURE}")"
rm -f "${HOME}/.local/bin/fzf"

# 6–7. No published digest.
: > "${CALL_LOG}"
API_JSON="$(api_json v0.0.1 "${fzf_url}" null)"
_fzf-install-binary >/dev/null 2>&1 \
    && fail "fzf, no digest: install succeeded" \
    || ok "fzf, no digest: refused"
[[ ! -s "${CALL_LOG}" && ! -e "${HOME}/.local/bin/fzf" ]] \
    && ok "fzf, no digest: nothing downloaded or installed" \
    || fail "fzf, no digest: calls: $(cat "${CALL_LOG}")"

# 8. Wrong digest.
: > "${CALL_LOG}"
API_JSON="$(api_json v0.0.1 "${fzf_url}" "\"sha256:${wrong_sha}\"")"
_fzf-install-binary >/dev/null 2>&1 || true
[[ ! -e "${HOME}/.local/bin/fzf" ]] && grep -q "^fetch_verified ${fzf_url} " "${CALL_LOG}" \
    && ok "fzf, wrong digest: verified through _wb_fetch_verified, nothing installed" \
    || fail "fzf, wrong digest: calls: $(cat "${CALL_LOG}")"

# 9. Right digest.
: > "${CALL_LOG}"
API_JSON="$(api_json v0.0.1 "${fzf_url}" "\"sha256:${fzf_sha}\"")"
_fzf-install-binary >/dev/null 2>&1
[[ -x "${HOME}/.local/bin/fzf" ]] && grep -q "^fetch_verified ${fzf_url} ${fzf_sha}$" "${CALL_LOG}" \
    && ok "fzf, matching digest: verified and installed" \
    || fail "fzf, matching digest: calls: $(cat "${CALL_LOG}")"

# 10. The releases-API request fails closed (curl -f exit 22, empty body).
curl() { return 22; }
: > "${CALL_LOG}"
rm -f "${HOME}/.local/bin/fzf"
_fzf-install-binary >/dev/null 2>&1 \
    && fail "fzf: a failed releases-API request reported success" \
    || ok "fzf: a failed releases-API request returns non-zero"

echo
echo "==============================="
echo "Total OK/FAIL checks: ${check_no}, failed: ${FAILED}"
echo "==============================="
[[ "${FAILED}" -eq 0 ]]
