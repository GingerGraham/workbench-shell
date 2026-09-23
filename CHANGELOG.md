# Changelog

All notable changes to `workbench-shell` are documented here.

## [Unreleased]

## [0.6.1] - 2026-09-23

### Fixed

- **`reset-shell`/`rs` no longer open a pager or dump the full aliases
  listing.** Both now call `get-functions --no-pager --no-aliases`
  instead of a bare `get-functions`, matching the summary a fresh shell
  already shows you (`WORKBENCH_SHOW_FUNCTIONS`'s startup banner in
  `workbench-core`) rather than inheriting `wb functions`' interactive
  pager and full output once `workbench-core` gained one. `aliases` is
  unchanged — it's still the full listing, by design. Requires a
  `workbench-core` release carrying its `docs/decisions-log.md`
  D72/D73 fix; on an older `workbench-core`, the two flags are silently
  ignored (no error, no regression).

## [0.6.0] - 2026-09-23

### Added

- **Manual `workflow_dispatch` release override.** `release.yml` now
  accepts a `bump_type` (patch/minor/major) input to force a release
  through `workbench-core`'s reusable `module-release.yml`, regardless of
  what Conventional Commits since the last tag would compute — a floor,
  never a downgrade of a higher severity already pending. Manual dispatch
  only runs from `main`. See `workbench-core`'s `docs/decisions-log.md` D67.

## [0.5.1] - 2026-09-16

### Fixed

- **`open-workspace` (`shell/editors.sh`) no longer listed when unusable.**
  Added `_open-workspace-available()`, a hand-written predicate mirroring
  the function's own `code`/`code-insiders` OR-check, so listings hide it
  on hosts with neither installed instead of showing a function that
  would immediately fail its own preflight. One module's slice of the
  shared `_<name>-available` predicate convention landing in
  `workbench-core` (`lib/core/functions.sh`).

## [0.5.0] - 2026-09-15

### Added

- **`nvim` added to `shell/editors.sh`'s `VISUAL` election** — new
  candidate between `code`/`code-insiders` (GUI sessions only) and the
  bare `vim` fallback, guarded on `nvim` actually being installed, and
  checked regardless of whether a GUI session is present. Part of #2.
- **`open-workspace`** (`shell/editors.sh`) — VS Code workspace picker,
  ported from workbench-precursor's `core/functions.sh`. Closes #8 (in
  part — `plain-shell`/`pretty-shell` land in `workbench-core` instead,
  see its own CHANGELOG).
- **`get-python-versions`, `get-public-ip`** (`shell/aliases.sh`) — ported
  from workbench-precursor's `core/functions.sh`. Closes #8 (in part).

### Fixed

- **`shell/editors.sh` respects a pre-set `VISUAL`.** The election
  previously overwrote `VISUAL` unconditionally in its GUI branch even
  when the user had already set one via `overrides.sh` — fixed to check
  first, election only runs when `VISUAL` is genuinely unset. Documented
  in `overrides.sh` and `README.md`. Closes #2.
- **Plain-mode prompt guard** (`shell/omp.sh`/`starship.sh`/`omz.sh`) —
  each now no-ops when `WORKBENCH_PLAIN_SHELL=true`, so `workbench-core`'s
  new `plain-shell` function actually produces a bare prompt instead of
  being silently overwritten by whichever engine's render hook was
  already live.

## [0.4.1] - 2026-09-15

### Added

- **Agent-instruction files** (`AGENTS.md`, `CLAUDE.md`,
  `.github/copilot-instructions.md`,
  `.claude/skills/conventional-commits/SKILL.md`) — ports
  `workbench-core`'s D32 agent-instruction topology to this repo. See
  `workbench-core`'s `docs/decisions-log.md` D58.
- **Repo governance files** (`.github/PULL_REQUEST_TEMPLATE.md`,
  `.github/ISSUE_TEMPLATE/{bug_report,feature_request,config}.yml`,
  `.github/CODEOWNERS`, `CONTRIBUTING.md`, `SECURITY.md`) — ports
  `workbench-core`'s D31 governance-file topology to this repo,
  piloted on `workbench-git` first. See `workbench-core`'s
  `docs/decisions-log.md` D60.

### Fixed

- **`install-oh-my-posh`, `install-starship`, and the direnv install-script
  fallback no longer pipe a downloaded install script straight into
  `bash`/`sh`** — each now downloads to a temp file first (via
  `_download_file_robust` where a curl path is available), verifies the
  download landed and is non-empty, then executes the file. Closes a
  `scan-patterns` CI finding (remote-script-execution pattern); a
  truncated or failed download can no longer be silently piped into a
  shell.

## [0.4.0] - 2026-09-12

### Changed

- **`tmux.conf`/`vimrc` are now deployed once and freely editable**
  (`mode: copy`), matching `starship.toml`/`direnv.toml` — previously
  `mode: link`, permanently synced with the module and impossible to
  customise. Restore either to the workbench default any time with `wb
  module reset shell tmux.conf` / `wb module reset shell .vimrc`
  (workbench-core ARCHITECTURE.md §12 D51).

  **Migration for existing installs:** this does not happen
  automatically — an ordinary sync leaves a pre-existing `mode: link`
  destination exactly as it was, deliberately, so it can't silently
  discard a change made through the old symlink. Run `wb module reset
  shell tmux.conf` and `wb module reset shell .vimrc` once, by hand, to
  convert them to real, detached, editable files.

## [0.3.0] - 2026-09-11

### Added

- **Prompt-engine election is now overridable** — set
  `WORKBENCH_OVERRIDE_PROMPT_ENGINE` (`omp`, `starship`, or `omz`) in
  `~/.config/workbench/local/overrides/shell.sh` to force a specific
  engine regardless of what's installed or the register-order election.
  Falls through to no prompt engine (never silently back to the
  election) if the named engine isn't actually installed. New
  `overrides_src: shell/overrides.sh` ships a commented template for
  this plus `OMP_THEME`/`ZSH_THEME` (workbench-core ARCHITECTURE.md §12
  D48). `ZSH_THEME` and oh-my-zsh's `plugins` array are no longer
  hardcoded, unconditional literals — both now respect a pre-set value.
  `set-omp-theme-permanent` now persists into this new overrides file
  instead of the shared `~/.config/workbench/local/settings.sh`.

### Changed

- **Manifest renamed** from `.dotfiles-sync.yml` to `workbench.yml`
  (`version: 2`) — no functional change, identical field set
  (workbench-core ARCHITECTURE.md §12 D46). Prompt-engine election
  overrides land in a separate, immediately-following change.

## [0.2.0] - 2026-09-09

### Added

- Added `installed-oh-my-posh`, `installed-starship`, `installed-oh-my-zsh`,
  `installed-zsh`, `installed-zsh-default-shell`, `installed-direnv`,
  `installed-fzf`, `installed-neovim` — reports install status to
  `wb tools upgrade`/`wb tools list --status` (workbench-core §12 D43).
  `install-zsh-plugins` deliberately has no predicate — see
  shell/installers.sh comment for why.

## [0.1.0] - 2026-09-09

### Added

- Initial decomposition from `workbench-precursor` (Wave C): core aliases,
  bash/zsh-specific tweaks, the self-electing prompt-engine trio
  (oh-my-posh/starship/oh-my-zsh), zsh plugins (autosuggestions + syntax
  highlighting), direnv/fzf shell integration, editor environment
  defaults, `tmux.conf`/`vimrc`/`starship.toml`/`direnv.toml`, and
  `install-oh-my-posh`/`install-starship`/`install-oh-my-zsh`/`install-zsh`/
  `install-zsh-default-shell`/`install-zsh-plugins`/`install-direnv`/
  `install-fzf`/`install-neovim`.

### Changed

- Prompt-engine election is now self-contained in each of
  `omp.sh`/`starship.sh`/`omz.sh` (each checks for higher-priority engines
  itself) rather than decided by `loader.sh` — `workbench-core`'s loader
  has no hardcoded per-module branching (principle 4).
- `set-omp-theme-permanent` now persists via
  `~/.config/workbench/local/settings.sh` instead of editing `omp.sh` in
  place — the latter lives inside an immutable per-sync snapshot under
  `workbench-core` and would be silently discarded on the next sync.
- `direnv-init-project`'s generated-`.envrc` detection now matches
  `workbench-git`'s marker (`# Generated by workbench-git`).
- `WORKBENCH_OS`/`WORKBENCH_DISTRO`/`WORKBENCH_SHELL`/`WORKBENCH_ARCH`
  replace `DOTFILES_OS`/`DOTFILES_DISTRO`/`DOTFILES_SHELL`.
- `files/direnv.toml`'s `[whitelist]` prefix is now commented out by
  default instead of shipping a non-functional `~/Projects` entry —
  direnv does not expand `~` in `direnv.toml`, so that default silently
  matched nothing. Documented in the file and the README as something you
  enable yourself with your own fully-expanded `projects_base`.
