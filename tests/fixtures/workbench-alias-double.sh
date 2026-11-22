# shellcheck shell=bash
# tests/fixtures/workbench-alias-double.sh — a stand-in for workbench-core's
# workbench_alias_define and workbench_alias_is_ours (Core API 1.10, D124),
# for the suites here that run without core. Written to the contract in
# core's contracts/core-api.md, in the same words; core's own tests cover the
# real helper.
#
# A name is free when workbench defined it earlier in this shell, nothing
# uses it, or an alias exists whose definition is identical. It is taken when
# a function of that name exists or a different alias does; the clash is
# recorded in WORKBENCH_ALIAS_CLASHES (name|module|kind|value) and the
# existing definition stays. Source this file; it works in bash and zsh.
WORKBENCH_ALIASES_OURS="${WORKBENCH_ALIASES_OURS:-}"
WORKBENCH_ALIAS_CLASHES="${WORKBENCH_ALIAS_CLASHES:-}"
workbench_alias_define() {
    local name="$1" module="$2" value="$3" kind existing wanted
    # shellcheck disable=SC2139  # the value is meant to expand now, as a plain alias would
    case " ${WORKBENCH_ALIASES_OURS} " in
        *" ${name} "*) builtin alias "${name}=${value}"; return 0 ;;
    esac
    if builtin typeset -f "${name}" >/dev/null 2>&1; then
        kind="function"
    elif builtin alias "${name}" >/dev/null 2>&1; then
        existing="$(builtin alias "${name}")"
        # shellcheck disable=SC2139  # same
        wanted="$( builtin unalias "${name}"; builtin alias "${name}=${value}"; builtin alias "${name}" )"
        if [[ "${existing}" == "${wanted}" ]]; then
            WORKBENCH_ALIASES_OURS="${WORKBENCH_ALIASES_OURS} ${name}"
            return 0
        fi
        kind="alias"
    else
        # shellcheck disable=SC2139  # same
        builtin alias "${name}=${value}"
        WORKBENCH_ALIASES_OURS="${WORKBENCH_ALIASES_OURS} ${name}"
        return 0
    fi
    WORKBENCH_ALIAS_CLASHES="${WORKBENCH_ALIAS_CLASHES}${name}|${module}|${kind}|${value}
"
    return 1
}
workbench_alias_is_ours() {
    case " ${WORKBENCH_ALIASES_OURS} " in
        *" ${1} "*) return 0 ;;
    esac
    return 1
}
