#!/usr/bin/env bash
# tests/check-fzf-defaults.sh — workbench-shell, workbench-core D110.
#
# shell/fzf.sh sets each FZF_* variable only when it is empty or unset, so a
# host that already configured fzf keeps its settings. On a host with none
# of them set, every default is exported with the value it always had, and a
# reload leaves them as they are. A stub fd and bat on PATH make the fd and
# preview defaults apply; there is no fzf on PATH, so the shell integration
# is skipped (tests/check-fzf-integration.sh covers that). bash and zsh both
# run; SKIP: only when zsh is not installed.
# Plain bash, numbered OK:/FAIL: checks, no framework.
#
# SC2015: '[[ cond ]] && ok || fail' is this suite's assertion idiom.
# SC2016: the generated script text is expanded by the shell it runs in.
# shellcheck disable=SC2015,SC2016
set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." >/dev/null 2>&1 && pwd)"

FAILED=0
check_no=0
ok()   { check_no=$((check_no + 1)); echo "OK:   [$check_no] $*"; }
fail() { check_no=$((check_no + 1)); echo "FAIL: [$check_no] $*"; FAILED=$((FAILED + 1)); }

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
mkdir -p "${WORK}/bin" "${WORK}/home"
for tool in fd bat; do
    printf '#!/usr/bin/env bash\nexit 0\n' > "${WORK}/bin/${tool}"
    chmod +x "${WORK}/bin/${tool}"
done

VARS="FZF_DEFAULT_OPTS FZF_DEFAULT_COMMAND FZF_CTRL_T_COMMAND FZF_ALT_C_COMMAND FZF_CTRL_T_OPTS"
D_OPTS='--height 40% --layout=reverse --border'
D_CMD='fd --type f --hidden --follow --exclude .git'
D_ALTC='fd --type d --hidden --follow --exclude .git'
D_PREVIEW="--preview 'bat --color=always --style=header,grid --line-range :500 {}'"

# run_fzf <shell> <passes> [VAR=value ...] — a clean environment with the
# given FZF_* variables, fzf.sh sourced <passes> times, then one
# "NAME=value" line per variable.
run_fzf() {
    local shell_bin="$1" passes="$2" n
    shift 2
    local script="${WORK}/case.sh"
    {
        echo 'log_debug() { :; }; log_warn() { :; }'
        for ((n = 0; n < passes; n++)); do
            echo "WORKBENCH_SHELL='${shell_bin}' source '${REPO_ROOT}/shell/fzf.sh'"
        done
        for v in ${VARS}; do
            printf 'printf "%%s=%%s\\n" %s "${%s-<unset>}"\n' "${v}" "${v}"
        done
    } > "${script}"
    env -i HOME="${WORK}/home" PATH="${WORK}/bin:/usr/bin:/bin" "$@" "${shell_bin}" "${script}" 2>&1
}

value_of() { printf '%s\n' "$1" | grep "^$2=" | sed "s/^$2=//"; }

for sh in bash zsh; do
    if ! command -v "${sh}" &>/dev/null; then
        echo "SKIP: ${sh} not installed"
        continue
    fi

    # 1. Plain host: every default applied, with today's value.
    out="$(run_fzf "${sh}" 1)"
    [[ "$(value_of "${out}" FZF_DEFAULT_OPTS)" == "${D_OPTS}" \
        && "$(value_of "${out}" FZF_DEFAULT_COMMAND)" == "${D_CMD}" \
        && "$(value_of "${out}" FZF_CTRL_T_COMMAND)" == "${D_CMD}" \
        && "$(value_of "${out}" FZF_ALT_C_COMMAND)" == "${D_ALTC}" \
        && "$(value_of "${out}" FZF_CTRL_T_OPTS)" == "${D_PREVIEW}" ]] \
        && ok "${sh}: nothing set: all five defaults applied, with their usual values" \
        || fail "${sh}: nothing set: ${out}"

    # 2. Each variable pre-set on its own: kept, the other four defaulted.
    for var in ${VARS}; do
        out="$(run_fzf "${sh}" 1 "${var}=host-${var}")"
        [[ "$(value_of "${out}" "${var}")" == "host-${var}" ]] \
            && ok "${sh}: a host-set ${var} is kept" \
            || fail "${sh}: ${var} was overridden: $(value_of "${out}" "${var}")"
    done

    # 3. A set-but-empty variable counts as unset.
    out="$(run_fzf "${sh}" 1 FZF_DEFAULT_OPTS=)"
    [[ "$(value_of "${out}" FZF_DEFAULT_OPTS)" == "${D_OPTS}" ]] \
        && ok "${sh}: an empty FZF_DEFAULT_OPTS gets the default" \
        || fail "${sh}: empty FZF_DEFAULT_OPTS: $(value_of "${out}" FZF_DEFAULT_OPTS)"

    # 4. A host FZF_DEFAULT_COMMAND flows into FZF_CTRL_T_COMMAND, as the
    #    default always derived it; the host value itself is untouched.
    out="$(run_fzf "${sh}" 1 FZF_DEFAULT_COMMAND=host-command)"
    [[ "$(value_of "${out}" FZF_DEFAULT_COMMAND)" == "host-command" \
        && "$(value_of "${out}" FZF_CTRL_T_COMMAND)" == "host-command" ]] \
        && ok "${sh}: a host FZF_DEFAULT_COMMAND is kept and used for Ctrl-T" \
        || fail "${sh}: host FZF_DEFAULT_COMMAND: ${out}"

    # 5. Reload: a second pass leaves everything as the first made it.
    first="$(run_fzf "${sh}" 1)"
    second="$(run_fzf "${sh}" 2)"
    [[ "${first}" == "${second}" ]] \
        && ok "${sh}: a reload changes nothing" \
        || fail "${sh}: reload differs: ${first} / ${second}"
done

echo
if [[ "${FAILED}" -eq 0 ]]; then
    echo "All ${check_no} checks passed."
    exit 0
else
    echo "${FAILED} of ${check_no} checks failed."
    exit 1
fi
