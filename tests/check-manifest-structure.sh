#!/usr/bin/env bash
# tests/check-manifest-structure.sh — workbench-shell
# Plain bash, numbered OK:/FAIL: checks, matching workbench-core's
# tests/check-*.sh convention (no framework). Structural checks only —
# lib/manifest/validate.sh (run separately by workbench-core's
# module-ci.yml, ARCHITECTURE.md §12 D40) is the authoritative shape/
# path-safety validator; this script's own value-add is the bash-3.2
# compat scan below, which validate.sh doesn't do.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

FAILED=0
check_no=0
ok()   { check_no=$((check_no + 1)); echo "OK:   [$check_no] $*"; }
fail() { check_no=$((check_no + 1)); echo "FAIL: [$check_no] $*"; FAILED=$((FAILED + 1)); }

# Manifest discovery, duplicated inline rather than sourced from
# workbench-core — this script runs standalone in this module's own CI,
# the same "must work without workbench-core installed alongside it"
# constraint lib/manifest/validate.sh's own header documents for its
# identical duplication (workbench-core ARCHITECTURE.md §12 D46). Checked
# in precedence order; .dotfiles-sync.yml is accepted unconditionally,
# the four new names only if they declare a top-level version: key.
_MANIFEST_CANDIDATES="workbench.yml workbench.yaml wb.yml wb.yaml .dotfiles-sync.yml"
MANIFEST=""
for _name in ${_MANIFEST_CANDIDATES}; do
    _candidate="${REPO_ROOT}/${_name}"
    [[ -f "${_candidate}" ]] || continue
    if [[ "${_name}" == ".dotfiles-sync.yml" ]]; then
        MANIFEST="${_candidate}"
        break
    fi
    grep -q '^version:' "${_candidate}" && { MANIFEST="${_candidate}"; break; }
done

if [[ -n "${MANIFEST}" ]]; then
    ok "manifest found ($(basename "${MANIFEST}"))"
else
    fail "no manifest found (checked ${_MANIFEST_CANDIDATES})"
fi

for key in version core_api register deploy; do
    if [[ -n "${MANIFEST}" ]] && grep -q "^${key}:" "${MANIFEST}"; then
        ok "manifest declares '${key}:'"
    else
        fail "manifest missing '${key}:'"
    fi
done

if [[ -n "${MANIFEST}" ]]; then
    while IFS= read -r src; do
        [[ -z "${src}" ]] && continue
        if [[ -f "${REPO_ROOT}/${src}" ]]; then
            ok "referenced file exists: ${src}"
        else
            fail "manifest references missing file: ${src}"
        fi
    done < <(grep -E '^[[:space:]]*(-[[:space:]]*)?src:' "${MANIFEST}" | sed -E 's/^[[:space:]]*-?[[:space:]]*src:[[:space:]]*//')
fi

declare -a _bash32_patterns=(
    "declare -A (associative arrays, bash 4+)|declare[[:space:]]+-A"
    "mapfile/readarray (bash 4+)|(^|[^[:alnum:]_])(mapfile|readarray)([^[:alnum:]_]|\$)"
    "shopt -s globstar (bash 4+)|shopt[[:space:]]+-s[[:space:]]+globstar"
    "\${var,,} / \${var^^} case conversion (bash 4+)|\\\$\\{[a-zA-Z_][a-zA-Z0-9_]*(,,|\\^\\^)"
    "declare -n nameref (bash 4.3+)|declare[[:space:]]+-n"
)
# Per-pattern extra excluded basename (index-aligned with
# _bash32_patterns; empty string = no extra exclusion), kept as a
# parallel array rather than packed into the same delimited string as
# the pattern above — several of these patterns contain literal "|"
# themselves (e.g. the mapfile/readarray alternation), which would
# collide with a shared field delimiter.
declare -a _bash32_extra_excludes=(
    ""
    "editors.sh"
    ""
    ""
    ""
)
# bash.sh's own `shopt -s globstar 2>/dev/null || true` is an interactive-
# shell convenience with a guarded fallback, not part of a bash-3.2-only
# Core API surface — excluded from this scan the same way workbench-core's
# own check-bash32-compat.sh excludes prose mentions in comments, since this
# repo's shell/ intentionally contains bash-version-conditional interactive
# tweaks (bash.sh/zsh.sh) rather than portable Core API code. editors.sh's
# open-workspace() is the same class of exception for mapfile specifically:
# it only calls mapfile behind its own `command -v mapfile` guard, with a
# bash-3.2-safe `$(...)` array-assignment fallback otherwise — excluded
# only from the mapfile/readarray pattern above (via
# _bash32_extra_excludes), so editors.sh still gets scanned for every
# other bash-4+ construct.
for _i in "${!_bash32_patterns[@]}"; do
    entry="${_bash32_patterns[${_i}]}"
    extra_exclude="${_bash32_extra_excludes[${_i}]}"
    desc="${entry%%|*}"
    pattern="${entry#*|}"
    hit=""
    while IFS= read -r -d '' f; do
        base="$(basename "${f}")"
        [[ "${base}" == "bash.sh" ]] && continue
        [[ -n "${extra_exclude}" && "${base}" == "${extra_exclude}" ]] && continue
        grep -vE '^[[:space:]]*#' "${f}" | grep -qE "${pattern}" && hit="${hit}${f}\n"
    done < <(find "${REPO_ROOT}/shell" -type f -print0 2>/dev/null)
    if [[ -n "${hit}" ]]; then
        fail "found ${desc} in: $(printf '%b' "${hit}" | tr '\n' ' ')"
    else
        ok "no ${desc} outside bash.sh's own guarded interactive-shell use"
    fi
done

echo
echo "==============================="
echo "Total OK/FAIL checks: ${check_no}, failed: ${FAILED}"
echo "==============================="
[[ "${FAILED}" -eq 0 ]]
