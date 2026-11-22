# shellcheck shell=bash
# tests/fixtures/workbench-alias-double.sh — a stand-in for workbench-core's
# workbench_alias_define and workbench_alias_is_ours (Core API 1.10, D124 and
# D125), for the suites here that run without core. It is the helper from
# workbench-core's lib/core/functions.sh, copied, so the suites see the same
# behaviour core has; core's own tests cover the helper itself.
#
# A name is free when workbench defined it earlier in this shell and it is
# still the alias workbench set (a reload refreshes it), when nothing uses it,
# or when an alias exists whose definition is identical. It is taken when a
# function of that name exists or a different alias does, which includes an
# alias the user has replaced since; the clash is recorded in
# WORKBENCH_ALIAS_CLASHES (name|module|kind|value) and the existing
# definition stays. Source this file; it works in bash and zsh.
WORKBENCH_ALIASES_OURS="${WORKBENCH_ALIASES_OURS:-}"
WORKBENCH_ALIAS_VALUES="${WORKBENCH_ALIAS_VALUES:-}"
WORKBENCH_ALIAS_CLASHES="${WORKBENCH_ALIAS_CLASHES:-}"

# workbench_alias_define <name> <module> <value>
# Returns 0 if the alias was defined (or refreshed, or already identical),
# 1 if an existing definition was left in place.
#
# The name is free when any of these holds:
#   1. workbench defined it earlier in this shell and it is still the alias
#      workbench set (a reload refreshes it, so a module update's new value
#      takes effect); or nothing of that name exists now,
#   2. nothing of that name exists,
#   3. an alias exists and its definition is identical to <value>'s.
# It is not free when a function of that name exists (never compared), or a
# different alias exists. That includes an alias workbench set earlier and
# the user has since replaced: it stops being workbench's, and a reload
# (`wb reload`) leaves the user's version in place. A command on PATH is not
# a clash: aliases such as cat, top and python shadow commands on purpose.
#
# `builtin` in front of alias, unalias and typeset is deliberate: this
# body must not be rewritten by a host alias of the same name (D110). The
# subshells below run only when an alias of that name already exists, so
# the normal path forks nothing.
workbench_alias_define() {
    local name="$1" module="$2" value="$3" existing wanted kind="" prev="" found="" line pair half
    local newline=$'\n' flat padded
    flat="${value//"${newline}"/ }"

    case " ${WORKBENCH_ALIASES_OURS:-} " in
        *" ${name} "*)
            # Defined by workbench earlier in this shell: a reload. Check
            # that what is there now is still what workbench set.
            if builtin typeset -f "${name}" >/dev/null 2>&1; then
                kind="function"
            elif builtin alias "${name}" >/dev/null 2>&1; then
                while IFS= read -r line; do
                    case "${line}" in
                        "${name}="*) prev="${line#*=}"; found="yes" ;;
                    esac
                done <<< "${WORKBENCH_ALIAS_VALUES:-}"
                # With no record (state from before values were kept) there
                # is nothing to compare, so refresh as a reload always did.
                if [[ -n "${found}" ]]; then
                    # One subshell prints the alias as it is, then as it
                    # would read had workbench's own value been set: the two
                    # texts, a newline between. Equal texts make the halves
                    # of that string equal, a newline in the middle (a value
                    # with a newline of its own is still compared whole).
                    # shellcheck disable=SC2139  # expands now, in a subshell that keeps nothing
                    pair="$( builtin alias "${name}"; builtin unalias "${name}"; builtin alias "${name}=${prev}"; builtin alias "${name}" )"  # wb-allow-bare-alias
                    half=$(( (${#pair} - 1) / 2 ))
                    if [[ $(( ${#pair} % 2 )) -ne 1 || "${pair:${half}:1}" != "${newline}" \
                        || "${pair:0:${half}}" != "${pair:$(( half + 1 ))}" ]]; then
                        kind="alias"
                    fi
                fi
            fi
            if [[ -z "${kind}" ]]; then
                # shellcheck disable=SC2139  # the value is meant to expand now, as a plain alias would
                builtin alias "${name}=${value}"  # wb-allow-bare-alias
                # A new record only when the value changed: a reload that
                # changes nothing adds nothing.
                [[ "${found}" == "yes" && "${prev}" == "${flat}" ]] \
                    || WORKBENCH_ALIAS_VALUES="${WORKBENCH_ALIAS_VALUES:-}${name}=${flat}${newline}"
                return 0
            fi
            # Replaced since by something of the user's: no longer ours.
            padded=" ${WORKBENCH_ALIASES_OURS:-} "
            padded="${padded/ ${name} / }"
            WORKBENCH_ALIASES_OURS="${padded% }"
            ;;
        *)
            if builtin typeset -f "${name}" >/dev/null 2>&1; then
                kind="function"
            elif builtin alias "${name}" >/dev/null 2>&1; then
                # An alias exists. Print what ours would look like, in this
                # shell's own format (bash: alias gd='git diff'; zsh:
                # gd='git diff'), and compare. Identical means there is
                # nothing to protect. The test above is a plain builtin and
                # forks nothing; only this branch forks, so a free name (the
                # normal case) costs no process.
                existing="$(builtin alias "${name}" 2>/dev/null)"
                # shellcheck disable=SC2139  # same: expands now, in a subshell that keeps nothing
                wanted="$( builtin unalias "${name}"; builtin alias "${name}=${value}"; builtin alias "${name}" )"  # wb-allow-bare-alias
                if [[ "${existing}" == "${wanted}" ]]; then
                    WORKBENCH_ALIASES_OURS="${WORKBENCH_ALIASES_OURS:-} ${name}"
                    WORKBENCH_ALIAS_VALUES="${WORKBENCH_ALIAS_VALUES:-}${name}=${flat}${newline}"
                    return 0
                fi
                kind="alias"
            else
                # shellcheck disable=SC2139  # same
                builtin alias "${name}=${value}"  # wb-allow-bare-alias
                WORKBENCH_ALIASES_OURS="${WORKBENCH_ALIASES_OURS:-} ${name}"
                WORKBENCH_ALIAS_VALUES="${WORKBENCH_ALIAS_VALUES:-}${name}=${flat}${newline}"
                return 0
            fi
            ;;
    esac

    # name|module|kind|value, one record per line. value is last so it may
    # contain "|"; a newline in it would split the record, so it is flat.
    WORKBENCH_ALIAS_CLASHES="${WORKBENCH_ALIAS_CLASHES:-}${name}|${module}|${kind}|${flat}${newline}"
    return 1
}

# workbench_alias_is_ours <name>
# True when workbench has defined an alias of that name in this shell.
workbench_alias_is_ours() {
    case " ${WORKBENCH_ALIASES_OURS:-} " in
        *" ${1} "*) return 0 ;;
    esac
    return 1
}
